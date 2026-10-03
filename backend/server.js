const CropIssue = require('./src/CropIssue');
const cron = require('node-cron');
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const axios = require('axios');
const bcrypt = require('bcryptjs');
const { GoogleGenerativeAI } = require('@google/generative-ai');
require('dotenv').config();

const { signup, signin } = require('./src/auth');
const { authenticate } = require('./src/authMiddleware');
const User = require('./src/User');
const Farm = require('./src/Farm');
const Crop = require('./src/Crop');
const Task = require('./src/Task');
const CommunityPost = require('./src/CommunityPost');
const Message = require('./src/Message');

const app = express();
const PORT = process.env.PORT || 5000;
const MONGO_URI = process.env.MONGO_URI;

// 1. CORS Configuration
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Body parser
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// Request logger
app.use((req, res, next) => {
  console.log(`📡 [${req.method}] ${req.url}`);
  next();
});

// ----------------------------------------------------
// 🧠 SMART GEMINI AI HELPER (Auto Fallback so it NEVER fails)
// ----------------------------------------------------
async function callGeminiAI(promptParts) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY is missing in .env');
  }
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const modelsToTry = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-1.5-flash'];

  let lastError = null;
  for (const modelName of modelsToTry) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(promptParts);
      const text = result.response.text();
      if (text && text.trim().length > 0) {
        return text.trim();
      }
    } catch (err) {
      lastError = err;
    }
  }
  throw lastError || new Error('All Gemini models failed');
}

// 2. Health check
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server is healthy and running' });
});

// 3. Authentication
app.post('/api/auth/signup', signup);
app.post('/api/auth/signin', signin);

// ----------------------------------------------------
// 🔊 NATIVE BENGALI VOICE STREAM API (FOR CHROME/WEB)
// ----------------------------------------------------
app.get('/api/tts', async (req, res) => {
  try {
    const text = req.query.text || '';
    if (!text) return res.status(400).send('No text provided');

    const ttsUrl = `https://translate.googleapis.com/translate_tts?ie=UTF-8&q=${encodeURIComponent(text)}&tl=bn&client=tw-ob`;
    const response = await axios.get(ttsUrl, {
      responseType: 'arraybuffer',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      },
    });

    res.set({
      'Content-Type': 'audio/mpeg',
      'Cache-Control': 'no-cache',
    });
    res.send(Buffer.from(response.data));
  } catch (err) {
    console.error('TTS Proxy Error:', err.message);
    res.status(500).send('TTS failed');
  }
});

app.get('/api/auth/me', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.user.id || req.user._id).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.status(200).json(user);
  } catch (err) {
    res.status(500).json({ error: 'Server error fetching profile' });
  }
});

app.put('/api/auth/me', authenticate, async (req, res) => {
  try {
    const { name, phone, village, district, bio, profilePicture } = req.body;
    const userId = req.user.id || req.user._id;

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { name, phone, village, district, bio, profilePicture },
      { new: true }
    ).select('-password');

    res.status(200).json({ message: 'Profile updated successfully!', user: updatedUser });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

app.delete('/api/auth/me', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    await User.findByIdAndDelete(userId);
    await Farm.deleteMany({ userId });
    await Crop.deleteMany({ userId });
    await Task.deleteMany({ userId });
    await CropIssue.deleteMany({ userId });
    await CommunityPost.deleteMany({ userId });
    res.status(200).json({ message: 'Account and all related data deleted forever!' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

// ----------------------------------------------------
// 5. FARM APIs
// ----------------------------------------------------
app.post('/api/farms', authenticate, async (req, res) => {
  try {
    const { name, landSize, unit, location, soilType, ph, description } = req.body;
    const userId = req.user.id || req.user._id;
    const newFarm = new Farm({
      userId,
      name,
      landSize: Number(landSize),
      unit: unit || 'শতাংশ (Decimal)',
      location: location || '',
      soilType: soilType || 'Loamy (দোআঁশ)',
      ph: ph ? Number(ph) : null,
      description: description || '',
    });
    await newFarm.save();
    res.status(201).json({ message: 'Farm created successfully', farm: newFarm });
  } catch (err) {
    res.status(500).json({ error: 'Failed to create farm' });
  }
});

app.get('/api/farmer/dashboard-summary', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const [activeFarmsCount, activeCrops, urgentTasks] = await Promise.all([
      Farm.countDocuments({ userId, status: 'active' }),
      Crop.find({ userId, status: 'In Progress' }).populate('farmId', 'name'),
      Task.find({ userId, isUrgent: true, status: 'Pending' }).populate('farmId', 'name'),
    ]);
    res.status(200).json({
      activeFarmsCount,
      activeCropsCount: activeCrops.length,
      urgentTasksCount: urgentTasks.length,
      urgentTasks,
      activeCrops,
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch summary' });
  }
});

app.get('/api/farms/my-farms', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const farms = await Farm.find({ userId, status: 'active' }).sort({ createdAt: -1 });
    res.status(200).json(farms);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch farms' });
  }
});

app.get('/api/farms/my-farms-with-expenses', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const farms = await Farm.find({ userId, status: 'active' }).sort({ createdAt: -1 });
    const farmsWithExpenses = await Promise.all(
      farms.map(async (farm) => {
        const crops = await Crop.find({ farmId: farm._id });
        const totalExpense = crops.reduce((sum, crop) => sum + (crop.totalExpense || 0), 0);
        return { ...farm.toObject(), totalExpense, cropsCount: crops.length };
      })
    );
    res.status(200).json(farmsWithExpenses);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch farms' });
  }
});

app.get('/api/crops/:id/issues', authenticate, async (req, res) => {
  try {
    const issues = await CropIssue.find({ cropId: req.params.id }).sort({ createdAt: -1 });
    res.status(200).json({ issues });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch issues' });
  }
});

// ----------------------------------------------------
// 🌍 GENERAL AI ADVISOR
// ----------------------------------------------------
app.post('/api/ai/general-advisor', authenticate, async (req, res) => {
  try {
    const { question, history } = req.body;
    const userId = req.user.userId || req.user.id || req.user._id;
    const [userFarms, userCrops] = await Promise.all([
      Farm.find({ userId: userId }),
      Crop.find({ userId: userId, status: 'In Progress' }).populate('farmId', 'name location'),
    ]);

    let farmsContext = 'The farmer has not registered any farms yet.';
    if (userFarms && userFarms.length > 0) {
      farmsContext =
        "Farmer's Farms:\n" +
        userFarms
          .map(
            (f) =>
              `- Farm: "${f.name}", Location: ${f.location}, Soil: ${f.soilType}, pH: ${f.ph}, Total Size: ${f.landSize} ${f.unit}`
          )
          .join('\n');
    }

    let cropsContext = 'No active crops currently.';
    if (userCrops && userCrops.length > 0) {
      cropsContext =
        "Farmer's Active Crops:\n" +
        userCrops
          .map(
            (c) =>
              `- Crop: "${c.cropType}" (Category: ${c.cropCategory}, Variety: ${c.variety || 'Local'}), Farm: "${c.farmId?.name || ''}", Plot Area: ${c.allocatedArea} ${c.areaUnit}, Seed/Sapling: ${c.seedQuantity} ${c.seedUnit} from ${c.seedSource}, Method: ${c.cultivationMethod}, Stage: ${c.currentStage}, Total Expense: ৳${c.totalExpense}`
          )
          .join('\n');
    }

    let historyText = '';
    if (history && history.length > 0) {
      historyText =
        'Previous Conversation:\n' +
        history
          .map((msg) => `${msg.sender === 'user' ? 'Farmer' : 'Advisor'}: ${msg.text}`)
          .join('\n') +
        '\n\n';
    }

    const prompt = `
      You are an Elite Agricultural Expert in Bangladesh.
      
      [FARMER'S DATABASE CONTEXT]
      ${farmsContext}
      ${cropsContext}
      
      CRITICAL RULES:
      1. Use the exact land size, soil type, crop variety, and seed info from the database context when answering.
      2. Keep response natural, respectful, and in simple Bengali. Do not sound robotic.
      
      ${historyText}
      Farmer's Question: "${question}"
    `;

    const answer = await callGeminiAI(prompt);
    res.status(200).json({ answer });
  } catch (error) {
    res.status(500).json({ error: 'সাময়িক সমস্যা হচ্ছে, একটু পর আবার চেষ্টা করুন।' });
  }
});

// ----------------------------------------------------
// 6. MASTER CROP PLAN GENERATOR (জমি ও বীজের তথ্যসহ রুটিন তৈরি)
// ----------------------------------------------------
async function generateAITasks(cropDetails, cropId, farmId, userId, startDate) {
  const {
    cropCategory,
    cropType,
    variety,
    allocatedArea,
    areaUnit,
    seedQuantity,
    seedUnit,
    seedSource,
    cultivationMethod,
  } = cropDetails;
  try {
    const prompt = `
      A farmer in Bangladesh is planting:
      - Category: ${cropCategory}
      - Crop: "${cropType}" (Variety: ${variety || 'Local'})
      - Cultivated Land Area: ${allocatedArea > 0 ? `${allocatedArea} ${areaUnit}` : 'Standard plot'}
      - Seed/Sapling Used: ${seedQuantity > 0 ? `${seedQuantity} ${seedUnit} (Source: ${seedSource})` : 'Standard'}
      - Cultivation Method: ${cultivationMethod}

      Generate a practical timeline of 5 to 7 crucial farming activities from planting to harvesting in Bengali.
      If it is a fruit tree/orchard (Mango, Malta, Guava), span tasks appropriately for sapling care.

      Return strictly a JSON array:
      [
        { "title": "...", "activityType": "Watering|Fertilizing|Maintenance|Pesticide|Harvesting|Monitoring", "daysAfterSowing": int, "isUrgent": boolean }
      ]
    `;

    const aiResponse = await callGeminiAI(prompt);
    const jsonMatch = aiResponse.match(/\[[\s\S]*\]/);
    const taskTemplates = JSON.parse(jsonMatch[0]);

    return taskTemplates.map((t) => ({
      userId,
      farmId,
      cropId,
      title: t.title,
      activityType: t.activityType,
      scheduledDate: new Date(startDate.getTime() + t.daysAfterSowing * 24 * 60 * 60 * 1000),
      isUrgent: t.isUrgent,
      status: 'Pending',
    }));
  } catch (error) {
    return [
      {
        userId,
        farmId,
        cropId,
        title: `${cropType}: প্রাথমিক সেচ ও জমি পর্যবেক্ষণ`,
        activityType: 'Watering',
        scheduledDate: new Date(startDate.getTime() + 2 * 86400000),
        isUrgent: true,
        status: 'Pending',
      },
      {
        userId,
        farmId,
        cropId,
        title: `${cropType}: সুষম সার প্রয়োগ (${allocatedArea > 0 ? `${allocatedArea} ${areaUnit}` : 'জমি অনুযায়ী'})`,
        activityType: 'Fertilizing',
        scheduledDate: new Date(startDate.getTime() + 15 * 86400000),
        isUrgent: false,
        status: 'Pending',
      },
    ];
  }
}

// ----------------------------------------------------
// 🧠 AI-DRIVEN & INSTANT DYNAMIC CROP STAGE EVALUATOR
// ----------------------------------------------------
const stageCacheByCropDay = new Map();

function getInstantBiologicalStage(crop, ageDays) {
  if (crop.status === 'Harvested' || (crop.currentStage && crop.currentStage.includes('Harvested'))) {
    return 'ফসল তোলা সম্পন্ন (Harvested)';
  }

  const name = `${crop.cropType || ''} ${crop.variety || ''}`.toLowerCase();
  const category = `${crop.cropCategory || ''}`.toLowerCase();
  const method = `${crop.cultivationMethod || ''}`.toLowerCase();
  const isSapling = method.includes('চারা') || method.includes('কলম') || method.includes('sapling');

  let duration = 90;
  if (/শাক|shak|spinach|ধনেপাতা|কলমি|পুঁই|মুলা/.test(name)) {
    duration = 35;
    const p = ageDays / duration;
    if (p <= 0.15) return 'অঙ্কুরোদগম (Germination)';
    if (p <= 0.35) return 'চারা অবস্থা (Seedling)';
    if (p <= 0.75) return 'পাতা ও ডগা বৃদ্ধি (Leaf Growth)';
    return 'সংগ্রহের উপযোগী (Ready to Harvest)';
  }

  if (category.includes('ফলমূল') || /মাল্টা|malta|আম|mango|পেয়ারা|guava|লিচু|লেবু|কুল|ড্রাগন|কলা|পেঁপে/.test(name)) {
    duration = 240;
    const p = ageDays / duration;
    if (p <= 0.12) return 'শিকড় ও চারা স্থাপন (Root Establishment)';
    if (p <= 0.45) return 'ডালপালা বিস্তার (Canopy Growth)';
    if (p <= 0.68) return 'মুকুল ও ফুল আসা (Flowering)';
    if (p <= 0.88) return 'ফল গঠন ও বৃদ্ধি (Fruit Development)';
    return 'ফল পরিপক্কতা (Fruit Maturation)';
  }

  if (/আলু|potato|পেঁয়াজ|onion|রসুন|garlic|আদা|হলুদ|কচু|গাজর/.test(name)) {
    duration = 90;
    const p = ageDays / duration;
    if (p <= 0.12) return 'অঙ্কুরোদগম (Sprouting)';
    if (p <= 0.35) return 'দৈহিক বৃদ্ধি (Vegetative Growth)';
    if (p <= 0.62) return 'কন্দ গঠন (Tuber Initiation)';
    if (p <= 0.85) return 'কন্দ বৃদ্ধি (Tuber Bulking)';
    return 'পরিপক্কতা (Maturation)';
  }

  if (/ধান|rice|paddy|গম|wheat|ভুট্টা|maize/.test(name)) {
    duration = 115;
    const p = ageDays / duration;
    if (p <= 0.15) return 'চারা অবস্থা (Seedling)';
    if (p <= 0.45) return 'কুশি ছড়ানো (Tillering)';
    if (p <= 0.68) return 'থোড় ও ফুল আসা (Booting & Flowering)';
    if (p <= 0.88) return 'দানা গঠন (Grain Filling)';
    return 'পাকা অবস্থা (Ripening)';
  }

  if (crop.expectedHarvestDate && crop.sowingDate) {
    const diff = Math.floor((new Date(crop.expectedHarvestDate) - new Date(crop.sowingDate)) / 86400000);
    if (diff >= 20) duration = diff;
  }

  const p = ageDays / duration;
  if (p <= 0.10) return isSapling ? 'চারা রোপণ (Transplanting)' : 'অঙ্কুরোদগম (Germination)';
  if (p <= 0.25) return 'চারা অবস্থা (Seedling)';
  if (p <= 0.55) return 'দৈহিক বৃদ্ধি (Vegetative Growth)';
  if (p <= 0.82) return 'ফুল ও ফল ধারণ (Flowering & Fruiting)';
  return 'পরিপক্কতা (Maturation)';
}

async function getAICropStage(crop) {
  if (!crop) return 'বৃদ্ধির ধাপ (Growing)';
  if (crop.status === 'Harvested' || (crop.currentStage && crop.currentStage.includes('Harvested'))) {
    return 'ফসল তোলা সম্পন্ন (Harvested)';
  }

  const ageDays = crop.sowingDate
    ? Math.max(0, Math.floor((new Date() - new Date(crop.sowingDate)) / 86400000))
    : 0;

  const cacheKey = `${crop._id.toString()}_${crop.cropType}_day_${ageDays}`;
  if (stageCacheByCropDay.has(cacheKey)) {
    return stageCacheByCropDay.get(cacheKey);
  }

  try {
    const prompt = `
Determine the current biological growth stage of this crop in Bangladesh:
- Crop Name: "${crop.cropType}" (Variety: "${crop.variety || 'Local'}", Category: "${crop.cropCategory || 'General'}")
- Planting Method: "${crop.cultivationMethod || 'Direct'}"
- Current Age: ${ageDays} days
Return ONLY the stage name in short Bangla with English in parentheses (max 4 words), e.g. দৈহিক বৃদ্ধি (Vegetative Growth) or কন্দ গঠন (Tuber Initiation). Output nothing else.
`.trim();

    const aiStageText = await callGeminiAI(prompt);
    const cleanedStage = (aiStageText || '')
      .replace(/[*#"`]/g, '')
      .replace(/^[-•]\s*/, '')
      .split('\n')[0]
      .trim();

    if (cleanedStage && cleanedStage.length > 2 && cleanedStage.length <= 65) {
      stageCacheByCropDay.set(cacheKey, cleanedStage);
      return cleanedStage;
    }
  } catch (err) {
    console.log('AI Stage fallback used:', err.message);
  }

  const fallbackStage = getInstantBiologicalStage(crop, ageDays);
  stageCacheByCropDay.set(cacheKey, fallbackStage);
  return fallbackStage;
}

// ----------------------------------------------------
// 🧠 THE CENTRAL SMART BRAIN (Helper Function for Auto & Manual Optimize)
// ----------------------------------------------------
async function optimizeCropTasksWithAI(cropId) {
  const crop = await Crop.findById(cropId).populate('farmId');
  if (!crop) throw new Error('Crop not found');

  const sowingDate = new Date(crop.sowingDate);
  const cropAgeDays = Math.max(0, Math.floor((new Date() - sowingDate) / (1000 * 60 * 60 * 24)));

  const latestStage = await getAICropStage(crop);
  if (latestStage && crop.currentStage !== latestStage) {
    crop.currentStage = latestStage;
    await crop.save();
  }

  const plotArea =
    crop.allocatedArea && crop.allocatedArea > 0
      ? `${crop.allocatedArea} ${crop.areaUnit || 'শতাংশ'}`
      : `${crop.farmId?.landSize || 'নির্ধারিত'} ${crop.farmId?.unit || 'একর'}`;

  const seedInfo =
    crop.seedQuantity && crop.seedQuantity > 0
      ? `${crop.seedQuantity} ${crop.seedUnit || ''} (উৎস: ${crop.seedSource || 'স্থানীয়'})`
      : crop.seedSource || 'সাধারণ বীজ/চারা';

  const soilInfo = `মাটির ধরন: ${crop.farmId?.soilType || 'দোআঁশ'}, pH: ${crop.farmId?.ph || 'স্বাভাবিক'}`;

  const completedTasks = await Task.find({ cropId: crop._id, status: 'Completed' })
    .sort({ scheduledDate: -1 })
    .limit(12);

  let taskHistoryText = 'No tasks completed yet.';
  if (completedTasks.length > 0) {
    taskHistoryText = completedTasks
      .map((t) => `- [${t.activityType}] ${t.title} (Done on: ${t.scheduledDate.toISOString().split('T')[0]})`)
      .join('\n');
  }

  const pendingTasks = await Task.find({ cropId: crop._id, status: 'Pending' });
  let pendingTasksText = 'No pending tasks.';
  if (pendingTasks.length > 0) {
    pendingTasksText = pendingTasks
      .map((t) => `ID: ${t._id}, Title: "${t.title}", Date: ${t.scheduledDate.toISOString().split('T')[0]}, Type: ${t.activityType}`)
      .join('\n');
  }

  const location = crop.farmId?.location || 'Khulna';
  let weatherSummary = 'Normal and clear weather for next 3 days.';
  try {
    const weatherUrl = `https://api.openweathermap.org/data/2.5/forecast?q=${encodeURIComponent(location)},BD&units=metric&appid=${process.env.WEATHER_API_KEY}`;
    const weatherRes = await axios.get(weatherUrl);
    const list = weatherRes.data.list || [];

    const summarizeDay = (slice, label) => {
      if (!slice || slice.length === 0) return `${label}: Clear`;
      const hasStorm = slice.some((f) => f.weather[0].id >= 200 && f.weather[0].id < 300);
      const hasHeavyRain = slice.some((f) => f.weather[0].id >= 502 && f.weather[0].id < 600);
      const hasLightRain = slice.some((f) => f.weather[0].id >= 300 && f.weather[0].id <= 501);
      if (hasStorm) return `${label}: Severe Storm / বজ্রঝড়`;
      if (hasHeavyRain) return `${label}: Heavy Rain / ভারী বৃষ্টি`;
      if (hasLightRain) return `${label}: Light Rain / হালকা বৃষ্টি`;
      return `${label}: Clear & Sunny / রৌদ্রোজ্জ্বল`;
    };

    const day0 = summarizeDay(list.slice(0, 8), 'Today (offsetDays: 0)');
    const day1 = summarizeDay(list.slice(8, 16), 'Tomorrow (offsetDays: 1)');
    const day2 = summarizeDay(list.slice(16, 24), 'Day After Tomorrow (offsetDays: 2)');
    weatherSummary = `${day0} | ${day1} | ${day2}`;
  } catch (err) {
    console.log(`⚠️ Weather error for ${location}`);
  }

  const prompt = `
    You are an Elite Agricultural Specialist guiding a farmer in Bangladesh to MAXIMIZE YIELD and PREVENT CROP LOSS.
    Today's Date: ${new Date().toISOString().split('T')[0]}
    
    [CROP & FARM PROFILE]
    - Crop Category: "${crop.cropCategory || 'শাকসবজি'}"
    - Crop Name: "${crop.cropType}" (Variety: "${crop.variety || 'দেশি/স্থানীয়'}")
    - Current Stage: ${crop.currentStage} (Age: ${cropAgeDays} days)
    - Cultivated Land Area: ${plotArea}
    - Seed/Sapling Details: ${seedInfo}
    - Cultivation Method: ${crop.cultivationMethod || 'মাঠে চাষ'}
    - Soil Condition: ${soilInfo}
    - Farmer's Note: "${crop.description || 'None'}"
    - 3-Day Weather Forecast (${location}): ${weatherSummary}

    [COMPLETED TASKS HISTORY]
    ${taskHistoryText}

    [PENDING & OVERDUE TASKS]
    ${pendingTasksText}

    Return EXACTLY ONE JSON object:
    {
      "pendingUpdates": [
        { "id": "task_id", "action": "Delete" | "Reschedule" | "Keep", "newDateOffsetDays": 0 }
      ],
      "newTasks": [
        {
          "title": "Short Task Title in Bengali",
          "activityType": "Monitoring | Fertilizing | Pesticide | Watering | Maintenance | Harvesting",
          "offsetDays": 0,
          "isUrgent": true/false,
          "howToGuide": "Detailed instruction and reason in Bengali tailored to ${plotArea} land."
        }
      ]
    }
  `;

  const aiResponse = await callGeminiAI(prompt);
  const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);

  let updatedCount = 0,
    deletedCount = 0,
    newCreatedCount = 0;

  if (jsonMatch) {
    const aiData = JSON.parse(jsonMatch[0]);

    if (aiData.pendingUpdates && Array.isArray(aiData.pendingUpdates)) {
      for (let update of aiData.pendingUpdates) {
        const task = pendingTasks.find((t) => t._id.toString() === update.id);
        if (!task) continue;

        if (update.action === 'Delete') {
          await Task.findByIdAndDelete(task._id);
          deletedCount++;
        } else if (update.action === 'Reschedule') {
          const newDate = new Date();
          newDate.setDate(newDate.getDate() + (Number(update.newDateOffsetDays) || 1));
          task.scheduledDate = newDate;
          if (!task.title.includes('(সময় পরিবর্তিত)')) {
            task.title = task.title.replace('[AI Update]', '').trim() + ' (সময় পরিবর্তিত)';
          }
          await task.save();
          updatedCount++;
        }
      }
    }

    if (aiData.newTasks && Array.isArray(aiData.newTasks)) {
      const targetFarmId = crop.farmId?._id || crop.farmId;
      for (let nTask of aiData.newTasks) {
        if (!nTask.title || nTask.title.trim() === '') continue;

        const newDate = new Date();
        newDate.setDate(newDate.getDate() + (Number(nTask.offsetDays) || 0));

        const newTask = new Task({
          userId: crop.userId,
          farmId: targetFarmId,
          cropId: crop._id,
          title: nTask.title.trim(),
          activityType: nTask.activityType || 'Monitoring',
          description: nTask.howToGuide || '',
          scheduledDate: newDate,
          isUrgent: nTask.isUrgent === true,
          status: 'Pending',
        });
        await newTask.save();
        newCreatedCount++;
      }
    }
  }

  return { updatedCount, deletedCount, newCreatedCount };
}

// ----------------------------------------------------
// 10. MANUAL AI TASK OPTIMIZER (Button Click)
// ----------------------------------------------------
app.post('/api/tasks/optimize-weather', authenticate, async (req, res) => {
  try {
    const { cropId } = req.body;
    if (!cropId) return res.status(400).json({ error: 'Crop ID is required.' });

    const metrics = await optimizeCropTasksWithAI(cropId);

    if (metrics.updatedCount === 0 && metrics.deletedCount === 0 && metrics.newCreatedCount === 0) {
      return res.status(200).json({ message: 'আপনার বর্তমান শিডিউল একদম ঠিক আছে! নতুন কোনো পরিবর্তনের দরকার নেই।' });
    }

    res.status(200).json({
      message: `কাজের তালিকা সমন্বয় করা হয়েছে! ${metrics.deletedCount}টি বাতিল কাজ মুছে ফেলা হয়েছে, ${metrics.updatedCount}টি রিশিডিউল করা হয়েছে এবং ${metrics.newCreatedCount}টি নতুন গাইড যুক্ত করা হয়েছে।`,
    });
  } catch (err) {
    console.error('Manual Optimizer Error:', err);
    res.status(500).json({ error: 'Failed to connect to AI Brain.' });
  }
});

// ----------------------------------------------------
// 12. DAILY AI CRON JOB (Autopilot Mode)
// ----------------------------------------------------
cron.schedule('0 6 * * *', async () => {
  try {
    console.log('⏰ [Cron] Daily AI Agronomist is waking up...');
    const activeCrops = await Crop.find({ status: 'In Progress' });

    if (activeCrops.length === 0) return console.log('✅ No active crops to check.');

    for (let crop of activeCrops) {
      try {
        await optimizeCropTasksWithAI(crop._id);
        console.log(`✅ [Autopilot] ${crop.cropType} এর শিডিউল ও ধাপ অটো-আপডেট করা হয়েছে।`);
      } catch (err) {
        console.log(`⚠️ Auto-optimize failed for ${crop._id}: ${err.message}`);
      }
    }
  } catch (error) {
    console.error('❌ Cron Job Master Error:', error.message);
  }
});

// ----------------------------------------------------
// ADMIN PANEL, ASK AI & OTHERS
// ----------------------------------------------------
app.get('/api/admin/issues/pending', authenticate, async (req, res) => {
  try {
    const pendingIssues = await CropIssue.find({ status: 'Pending_Expert' })
      .populate('userId', 'name phone district village')
      .populate({
        path: 'cropId',
        select: 'cropCategory cropType variety allocatedArea areaUnit seedQuantity seedUnit seedSource cultivationMethod currentStage sowingDate totalExpense farmId',
        populate: { path: 'farmId', select: 'name location landSize unit soilType ph' },
      })
      .sort({ createdAt: -1 });
    res.status(200).json({ issues: pendingIssues });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch issues.' });
  }
});

app.put('/api/admin/issues/:issueId/reply', authenticate, async (req, res) => {
  try {
    const { issueId } = req.params;
    const { expertReply, diseaseName, medicineAdvice, precaution } = req.body;
    const expertUserId = req.user.id || req.user._id;

    const existingIssue = await CropIssue.findById(issueId);
    if (!existingIssue) return res.status(404).json({ error: 'Issue not found' });

    const wasAlreadyResolved = existingIssue.status === 'Expert_Resolved';

    const expertUser = await User.findById(expertUserId);
    const expertSignature = expertUser
      ? `\n— ${expertUser.name} (${expertUser.designation || 'কৃষি বিশেষজ্ঞ'})`
      : '';

    let finalReply = expertReply || '';
    if (diseaseName || medicineAdvice || precaution) {
      const parts = [];
      if (diseaseName) parts.push(`🔍 রোগ/সমস্যা: ${diseaseName}`);
      if (medicineAdvice) parts.push(`💊 করণীয় ও মাত্রা: ${medicineAdvice}`);
      if (precaution) parts.push(`⚠️ সতর্কতা: ${precaution}`);
      finalReply = parts.join('\n\n');
    }

    if (!finalReply.trim()) {
      return res.status(400).json({ error: 'Reply message is required.' });
    }

    const cleanReplyText = finalReply.includes('— ')
      ? finalReply.trim()
      : `${finalReply.trim()}${expertSignature}`;

    const updatedIssue = await CropIssue.findByIdAndUpdate(
      issueId,
      {
        expertReply: cleanReplyText,
        status: 'Expert_Resolved',
        resolvedBy: expertUserId,
        resolvedAt: new Date(),
      },
      { new: true }
    );

    if (!wasAlreadyResolved && expertUser) {
      expertUser.resolvedIssuesCount = (expertUser.resolvedIssuesCount || 0) + 1;
      await expertUser.save();
    }

    res.status(200).json({
      message: wasAlreadyResolved
        ? '✅ প্রেসক্রিপশন সফলভাবে আপডেট করা হয়েছে!'
        : '✅ কৃষকের কাছে সফলভাবে আপনার প্রেসক্রিপশন পাঠানো হয়েছে!',
      issue: updatedIssue,
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to send reply.' });
  }
});

app.get('/api/admin/issues/all', async (req, res) => {
  try {
    const issues = await CropIssue.find()
      .populate('userId', 'name phone district village')
      .populate('assignedExpert', 'name email designation district phone')
      .populate('resolvedBy', 'name email designation district')
      .populate({
        path: 'cropId',
        select: 'cropCategory cropType variety allocatedArea areaUnit currentStage farmId',
        populate: { path: 'farmId', select: 'name location soilType ph' },
      })
      .sort({ createdAt: -1 });

    res.status(200).json(issues);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch all issues for admin.' });
  }
});

// ----------------------------------------------------
// 🩺 CROP DOCTOR
// ----------------------------------------------------
app.post('/api/crops/:id/issues/ask-ai', authenticate, async (req, res) => {
  try {
    const { issueText, imageBase64 } = req.body;
    const cropId = req.params.id;
    const crop = await Crop.findById(cropId).populate('farmId');
    if (!crop) return res.status(404).json({ error: 'Crop not found' });

    const userId = (req.user && (req.user.id || req.user.userId || req.user._id)) || crop.userId;

    const plotArea =
      crop.allocatedArea && crop.allocatedArea > 0
        ? `${crop.allocatedArea} ${crop.areaUnit || 'শতাংশ'}`
        : `${crop.farmId?.landSize || 'নির্ধারিত'} ${crop.farmId?.unit || 'একর'}`;

    const seedInfo =
      crop.seedQuantity && crop.seedQuantity > 0
        ? `${crop.seedQuantity} ${crop.seedUnit || ''} (উৎস: ${crop.seedSource || 'স্থানীয়'})`
        : crop.seedSource || 'সাধারণ বীজ/চারা';

    const prompt = `
      You are an Elite Agricultural Expert and Crop Doctor in Bangladesh.
      
      [CROP & FIELD INFORMATION]
      - Crop: "${crop.cropType}" (Category: ${crop.cropCategory || 'সাধারণ'}, Variety: ${crop.variety || 'স্থানীয়'})
      - Cultivated Area: ${plotArea}
      - Seed/Sapling Info: ${seedInfo}
      - Cultivation Method: ${crop.cultivationMethod || 'মাঠে চাষ'}, Current Stage: ${crop.currentStage}
      - Soil Type: ${crop.farmId?.soilType || 'দোআঁশ'}, Soil pH: ${crop.farmId?.ph || 'স্বাভাবিক'}, Location: ${crop.farmId?.location || 'Bangladesh'}

      Farmer says: "${issueText}"

      CRITICAL RULES:
      1. ONLY answer agriculture/farming questions. Refuse others politely in Bengali.
      2. Give direct, accurate, simple Bengali solutions without using robotic words.
      3. Mention specific medicines/fertilizers and calculate the dosage according to their ${plotArea} land area if applicable.
    `;

    let aiResponseText = '';
    if (imageBase64) {
      const imageParts = [{ inlineData: { data: imageBase64, mimeType: 'image/jpeg' } }];
      aiResponseText = await callGeminiAI([prompt, ...imageParts]);
    } else {
      aiResponseText = await callGeminiAI(prompt);
    }

    const newIssue = new CropIssue({
      userId,
      cropId,
      issueText,
      imageBase64,
      aiAdvice: aiResponseText,
      status: 'AI_Resolved',
    });
    await newIssue.save();

    res.status(200).json({ issueId: newIssue._id, answer: aiResponseText, message: 'Success' });
  } catch (error) {
    res.status(500).json({ error: 'সাময়িক সমস্যা হচ্ছে, একটু পর আবার চেষ্টা করুন।' });
  }
});

app.put('/api/issues/:issueId/ask-expert', authenticate, async (req, res) => {
  try {
    const { expertId } = req.body;
    const updateData = {
      needsExpert: true,
      status: 'Pending_Expert',
    };
    if (expertId) {
      updateData.assignedExpert = expertId;
    }

    const updatedIssue = await CropIssue.findByIdAndUpdate(req.params.issueId, updateData, {
      new: true,
    }).populate('assignedExpert', 'name designation district');

    if (!updatedIssue) return res.status(404).json({ error: 'Issue not found' });
    res.status(200).json({
      message: 'আপনার সমস্যাটি নির্বাচিত কৃষি বিশেষজ্ঞের কাছে পাঠানো হয়েছে!',
      issue: updatedIssue,
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to send to expert.' });
  }
});

// ----------------------------------------------------
// 🌱 SHARED CROP CATALOG & VALIDATION HELPERS
// ----------------------------------------------------
const DEFAULT_CROP_CATALOG = {
  'শাকসবজি (Vegetables)': [
    'আলু (Potato)',
    'টমেটো (Tomato)',
    'বেগুন (Brinjal)',
    'লাউ (Bottle Gourd)',
    'মিষ্টি কুমড়া (Pumpkin)',
    'ফুলকপি (Cauliflower)',
    'বাঁধাকপি (Cabbage)',
    'শসা (Cucumber)',
    'করলা (Bitter Gourd)',
    'ঢেঁড়স (Okra)',
    'লাল শাক (Red Amaranth)',
  ],
  'ফলমূল (Fruits)': [
    'তরমুজ (Watermelon)',
    'আম (Mango)',
    'পেঁপে (Papaya)',
    'কলা (Banana)',
    'পেয়ারা (Guava)',
    'মাল্টা (Malta)',
    'কুল/বরই (Jujube)',
    'লিচু (Lychee)',
    'আনারস (Pineapple)',
    'ড্রাগন ফল (Dragon Fruit)',
  ],
  'দানা শস্য (Grains & Paddy)': [
    'বোরো ধান (Boro Rice)',
    'আমন ধান (Aman Rice)',
    'আউশ ধান (Aus Rice)',
    'গম (Wheat)',
    'ভুট্টা (Maize)',
    'সরিষা (Mustard)',
    'মসুর ডাল (Lentil)',
    'মুগ ডাল (Mung Bean)',
    'সূর্যমুখী (Sunflower)',
  ],
  'মসলা জাতীয় (Spices)': [
    'কাঁচা মরিচ (Chili)',
    'পেঁয়াজ (Onion)',
    'রসুন (Garlic)',
    'আদা (Ginger)',
    'হলুদ (Turmeric)',
    'ধনিয়া (Coriander)',
    'কালোজিরা (Black Cumin)',
  ],
  'অন্যান্য (Others)': [
    'পাট (Jute)',
    'আখ (Sugarcane)',
    'পান (Betel Leaf)',
    'চিনাবাদাম (Peanut)',
    'তিল (Sesame)',
    'নেপিয়ার ঘাস (Napier Grass)',
  ],
};

app.get('/api/crops/catalog', authenticate, async (req, res) => {
  try {
    const catalog = JSON.parse(JSON.stringify(DEFAULT_CROP_CATALOG));
    const approvedCrops = await Crop.find({ isCatalogApproved: true }).select('cropCategory cropType');

    approvedCrops.forEach((item) => {
      const cat = (item.cropCategory || '').trim();
      const type = (item.cropType || '').trim();
      if (!cat || !type) return;

      if (!catalog[cat]) {
        catalog[cat] = [];
      }
      if (!catalog[cat].includes(type)) {
        catalog[cat].push(type);
      }
    });

    res.status(200).json(catalog);
  } catch (err) {
    res.status(200).json(DEFAULT_CROP_CATALOG);
  }
});

async function validateCropEntryWithAI(cropCategory, cropType) {
  try {
    if (DEFAULT_CROP_CATALOG[cropCategory] && DEFAULT_CROP_CATALOG[cropCategory].includes(cropType)) {
      return { isValid: true, normalizedCategory: cropCategory, normalizedCrop: cropType };
    }

    const prompt = `
      A farmer in Bangladesh entered a crop category and crop name in an agricultural app:
      Category: "${cropCategory}"
      Crop Name: "${cropType}"

      Check if both are valid, real-world agricultural/farming categories and crop/plant names.
      Return strictly a JSON object:
      {
        "isValid": true or false,
        "normalizedCategory": "Keep exact standard name if it matches শাকসবজি (Vegetables), ফলমূল (Fruits), দানা শস্য (Grains & Paddy), মসলা জাতীয় (Spices), অন্যান্য (Others), otherwise format nicely in Bengali",
        "normalizedCrop": "Clean Crop Name in Bengali"
      }
    `;

    const text = await callGeminiAI(prompt);
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      return JSON.parse(jsonMatch[0]);
    }
  } catch (e) {
    console.log('Catalog validation skipped:', e.message);
  }
  return { isValid: false, normalizedCategory: cropCategory, normalizedCrop: cropType };
}

// ----------------------------------------------------
// 🌱 ADD NEW CROP
// ----------------------------------------------------
app.post('/api/crops', authenticate, async (req, res) => {
  try {
    const {
      farmId,
      cropCategory,
      cropType,
      variety,
      allocatedArea,
      areaUnit,
      seedQuantity,
      seedUnit,
      seedSource,
      sowingDate,
      cultivationMethod,
      description,
    } = req.body;
    const userId = req.user.id || req.user._id;

    if (!farmId || !cropType || !sowingDate) {
      return res.status(400).json({ error: 'Farm, crop type, and sowing date required.' });
    }

    const rawCategory = (cropCategory || 'শাকসবজি (Vegetables)').trim();
    const rawCropType = cropType.trim();

    const validation = await validateCropEntryWithAI(rawCategory, rawCropType);
    const finalCategory = validation.isValid ? validation.normalizedCategory || rawCategory : rawCategory;
    const finalCropType = validation.isValid ? validation.normalizedCrop || rawCropType : rawCropType;

    const startDate = new Date(sowingDate);
    const cropDetailsObj = {
      cropCategory: finalCategory,
      cropType: finalCropType,
      variety: variety || '',
      allocatedArea: allocatedArea ? Number(allocatedArea) : 0,
      areaUnit: areaUnit || 'শতাংশ (Decimal)',
      seedQuantity: seedQuantity ? Number(seedQuantity) : 0,
      seedUnit: seedUnit || 'গ্রাম (gm)',
      seedSource: seedSource || 'স্থানীয় অনুমোদিত ডিলার',
      cultivationMethod: cultivationMethod || 'Open Field (মাঠ)',
    };

    const aiGeneratedTasks = await generateAITasks(cropDetailsObj, null, farmId, userId, startDate);

    let harvestDate = new Date(startDate);
    harvestDate.setDate(harvestDate.getDate() + 90);
    const harvestingTask = aiGeneratedTasks.find((t) => t.activityType === 'Harvesting');
    if (harvestingTask) harvestDate = new Date(harvestingTask.scheduledDate);

    const newCrop = new Crop({
      userId,
      farmId,
      ...cropDetailsObj,
      isCatalogApproved: validation.isValid === true,
      description: description || '',
      sowingDate: startDate,
      expectedHarvestDate: harvestDate,
      currentStage: 'Germination',
    });

    const ageDays = Math.max(0, Math.floor((new Date() - startDate) / 86400000));
    newCrop.currentStage = getInstantBiologicalStage(newCrop, ageDays);

    await newCrop.save();
    const tasksToSave = aiGeneratedTasks.map((t) => ({ ...t, cropId: newCrop._id }));
    await Task.insertMany(tasksToSave);

    res.status(201).json({ message: 'Crop added and Master Plan generated!', crop: newCrop });
  } catch (err) {
    console.error('Error adding crop:', err);
    res.status(500).json({ error: 'Failed to add crop' });
  }
});

app.get('/api/crops/my', authenticate, async (req, res) => {
  try {
    const crops = await Crop.find({ userId: req.user.id || req.user._id })
      .populate('farmId', 'name location')
      .sort({ createdAt: -1 });
    res.status(200).json(crops);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch crops' });
  }
});

// ----------------------------------------------------
// 🚀 CROP DETAILS API (Instant Load + Dynamic AI Stage Update)
// ----------------------------------------------------
app.get('/api/crops/:id/details', authenticate, async (req, res) => {
  try {
    const [crop, tasks] = await Promise.all([
      Crop.findById(req.params.id).populate('farmId', 'name location'),
      Task.find({ cropId: req.params.id }).sort({ scheduledDate: 1 }),
    ]);

    if (!crop) return res.status(404).json({ error: 'Crop not found' });

    const ageDays = crop.sowingDate
      ? Math.max(0, Math.floor((new Date() - new Date(crop.sowingDate)) / 86400000))
      : 0;
    const cacheKey = `${crop._id.toString()}_${crop.cropType}_day_${ageDays}`;

    // ১. ক্যাশে থাকলে অথবা পুরনো ইংরেজি 'Germination' থাকলে সাথে সাথে ফসলের বয়স ও জাত অনুযায়ী বাংলা ধাপ বসিয়ে দেওয়া
    if (stageCacheByCropDay.has(cacheKey)) {
      crop.currentStage = stageCacheByCropDay.get(cacheKey);
    } else if (!crop.currentStage || crop.currentStage === 'Germination' || !crop.currentStage.includes('(')) {
      crop.currentStage = getInstantBiologicalStage(crop, ageDays);
      await Crop.findByIdAndUpdate(crop._id, { currentStage: crop.currentStage });
    }

    // ২. সাথে সাথে রেসপন্স পাঠিয়ে ড্যাশবোর্ড ওপেন করা (যাতে ১ সেকেন্ডও ঘুরতে না হয়)
    res.status(200).json({ crop, tasks });

    // ৩. ব্যাকগ্রাউন্ডে AI দিয়ে ধাপটি আরও নিখুঁত করে ডাটাবেসে সেভ রাখা
    getAICropStage(crop)
      .then(async (aiStage) => {
        if (aiStage && crop.currentStage !== aiStage) {
          await Crop.findByIdAndUpdate(crop._id, { currentStage: aiStage });
        }
      })
      .catch(() => {});
  } catch (err) {
    console.error('Details Route Error:', err.message);
    res.status(500).json({ error: 'Failed to fetch crop details' });
  }
});

// 🚀 আপডেট করা খরচের API (Category সহ সেভ হবে)
app.post('/api/crops/:id/expenses', authenticate, async (req, res) => {
  try {
    const crop = await Crop.findById(req.params.id);
    if (!crop) return res.status(404).json({ error: 'Crop not found' });

    const expAmt = Number(req.body.amount);
    const category = req.body.category || 'Other';

    crop.expenses.unshift({
      title: req.body.title,
      category: category,
      amount: expAmt,
    });
    crop.totalExpense += expAmt;

    await crop.save();
    res.status(200).json(crop);
  } catch (err) {
    res.status(500).json({ error: 'Failed to add expense' });
  }
});

// 🚀 খরচের বিশ্লেষণ ও সাশ্রয়ী পরামর্শ জেনারেট করার API
app.post('/api/crops/:id/analyze-expenses', authenticate, async (req, res) => {
  try {
    const crop = await Crop.findById(req.params.id).populate('farmId');
    if (!crop) return res.status(404).json({ error: 'Crop not found' });

    if (!crop.expenses || crop.expenses.length === 0 || crop.totalExpense === 0) {
      return res.status(400).json({ error: 'বিশ্লেষণ করার জন্য কোনো খরচের হিসাব পাওয়া যায়নি।' });
    }

    const categoryTotals = {};
    crop.expenses.forEach((exp) => {
      const cat = exp.category || 'Other';
      categoryTotals[cat] = (categoryTotals[cat] || 0) + (exp.amount || 0);
    });

    const breakdownText = Object.entries(categoryTotals)
      .map(([cat, amt]) => {
        const pct = ((amt / crop.totalExpense) * 100).toFixed(1);
        return `- ${cat}: ৳${amt} (${pct}%)`;
      })
      .join('\n');

    const plotArea =
      crop.allocatedArea && crop.allocatedArea > 0
        ? `${crop.allocatedArea} ${crop.areaUnit || 'শতাংশ'}`
        : `${crop.farmId?.landSize || 'নির্ধারিত'} ${crop.farmId?.unit || 'একর'}`;

    const seedInfo =
      crop.seedQuantity && crop.seedQuantity > 0
        ? `${crop.seedQuantity} ${crop.seedUnit || ''} (${crop.seedSource || 'স্থানীয়'})`
        : 'উল্লেখ নেই';

    const prompt = `
      You are an Agricultural Economist & Crop Advisor in Bangladesh.
      - Crop: "${crop.cropType}" (Category: ${crop.cropCategory || 'সাধারণ'}, Variety: ${crop.variety || 'স্থানীয়'})
      - Stage/Status: ${crop.currentStage} (${crop.status})
      - Cultivated Land Area: ${plotArea}
      - Seed/Sapling Used: ${seedInfo}
      - Cultivation Method: ${crop.cultivationMethod || 'মাঠে চাষ'}
      - Total Expense: ৳${crop.totalExpense}
      
      Category-wise Expense Breakdown:
      ${breakdownText}

      Task:
      Analyze these farming expenses compared to their ${plotArea} land area and give a short, practical, and encouraging financial advice in simple Bengali (2 to 3 sentences max).
      Do NOT use robotic words like "AI". Point out which category took the highest percentage of cost and suggest a practical way to save 15%-25% cost next time.
    `;

    const aiAdvice = await callGeminiAI(prompt);

    crop.aiExpenseAnalysis = aiAdvice;
    await crop.save();

    res.status(200).json({ aiExpenseAnalysis: aiAdvice, crop });
  } catch (err) {
    console.error('Expense Analysis Error:', err);
    res.status(500).json({ error: 'হিসাব মূল্যায়ন করতে সমস্যা হয়েছে।' });
  }
});

// 🚀 ফসল কাটা সম্পন্ন (Harvest) করা এবং অটোমেটিক AI খরচ বিশ্লেষণ করা
app.put('/api/crops/:id/harvest', authenticate, async (req, res) => {
  try {
    const crop = await Crop.findById(req.params.id).populate('farmId');
    if (!crop) return res.status(404).json({ error: 'Crop not found' });

    crop.currentStage = 'ফসল তোলা সম্পন্ন (Harvested)';
    crop.status = 'Harvested';

    if (crop.expenses && crop.expenses.length > 0 && crop.totalExpense > 0) {
      try {
        const categoryTotals = {};
        crop.expenses.forEach((exp) => {
          const cat = exp.category || 'Other';
          categoryTotals[cat] = (categoryTotals[cat] || 0) + (exp.amount || 0);
        });

        const breakdownText = Object.entries(categoryTotals)
          .map(([cat, amt]) => {
            const pct = ((amt / crop.totalExpense) * 100).toFixed(1);
            return `- ${cat}: ৳${amt} (${pct}%)`;
          })
          .join('\n');

        const prompt = `
          You are an Agricultural Economist in Bangladesh. The farmer just harvested "${crop.cropType}".
          Total Expense: ৳${crop.totalExpense}
          Breakdown:
          ${breakdownText}
          Give a 2-3 sentence advice in simple Bengali pointing out where they spent the most and how to reduce cost by 15-25% next season.
        `;
        crop.aiExpenseAnalysis = await callGeminiAI(prompt);
      } catch (aiErr) {
        console.log('⚠️ Harvest AI Expense Analysis skipped:', aiErr.message);
      }
    }

    await crop.save();
    res.status(200).json({ message: 'ফসল সফলভাবে ঘরে তোলা হয়েছে (Harvested)!', crop });
  } catch (err) {
    res.status(500).json({ error: 'Failed to mark crop as harvested' });
  }
});

app.post('/api/crops/:id/notes', authenticate, async (req, res) => {
  try {
    const crop = await Crop.findById(req.params.id);
    if (!crop) return res.status(404).json({ error: 'Crop not found' });
    crop.diaryNotes.unshift({ note: req.body.note });
    await crop.save();
    res.status(200).json(crop);
  } catch (err) {
    res.status(500).json({ error: 'Failed to add note' });
  }
});

app.get('/api/tasks/my', authenticate, async (req, res) => {
  try {
    const tasks = await Task.find({ userId: req.user.id || req.user._id })
      .populate('cropId', 'cropType')
      .populate('farmId', 'name')
      .sort({ scheduledDate: 1 });
    res.status(200).json(tasks);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch tasks' });
  }
});

app.put('/api/tasks/:id/complete', authenticate, async (req, res) => {
  try {
    const task = await Task.findByIdAndUpdate(req.params.id, { status: 'Completed' }, { new: true });
    res.status(200).json({ message: 'Task marked as completed', task });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update task' });
  }
});

app.get('/api/admin/users', async (req, res) => {
  try {
    const users = await User.find().select('-password').sort({ createdAt: -1 });
    res.status(200).json(users);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

app.delete('/api/admin/users/:id', async (req, res) => {
  try {
    await User.findByIdAndDelete(req.params.id);
    res.status(200).json({ message: 'User deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// ----------------------------------------------------
// 👑 ADMIN: ইউজারকে EXPERT হিসেবে নিয়োগ ও পদবী/হটলাইন সেটআপ
// ----------------------------------------------------
app.put('/api/admin/users/:id/role', async (req, res) => {
  try {
    const {
      role,
      designation,
      specialization,
      hotlineNumber,
      whatsappNumber,
      dutyHours,
      district,
      isTopFarmer,
      badgeTitle,
    } = req.body;

    const existingUser = await User.findById(req.params.id);
    if (!existingUser) return res.status(404).json({ error: 'User not found' });

    const updateFields = {};
    if (role) updateFields.role = role;
    if (designation !== undefined) updateFields.designation = designation;
    if (specialization !== undefined) updateFields.specialization = specialization;
    if (hotlineNumber !== undefined) updateFields.hotlineNumber = hotlineNumber;
    if (whatsappNumber !== undefined) updateFields.whatsappNumber = whatsappNumber;
    if (dutyHours !== undefined) updateFields.dutyHours = dutyHours;
    if (district !== undefined) updateFields.district = district;
    if (isTopFarmer !== undefined) updateFields.isTopFarmer = isTopFarmer;

    if (role === 'expert') {
      updateFields.badgeTitle = badgeTitle || 'Verified Expert 👨‍🌾';
      if (!hotlineNumber && !existingUser.hotlineNumber) {
        updateFields.hotlineNumber = existingUser.phone;
      }
      if (!whatsappNumber && !existingUser.whatsappNumber) {
        updateFields.whatsappNumber = existingUser.phone;
      }
    } else if (role === 'farmer' && !badgeTitle) {
      updateFields.badgeTitle = 'Active Farmer';
    } else if (badgeTitle) {
      updateFields.badgeTitle = badgeTitle;
    }

    const updatedUser = await User.findByIdAndUpdate(req.params.id, updateFields, {
      new: true,
    }).select('-password');

    res.status(200).json({ message: 'Role and details updated!', user: updatedUser });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update role' });
  }
});

// 👑 ১. ADMIN: নতুন নিয়োগপ্রাপ্ত কৃষি বিশেষজ্ঞের (Expert) অ্যাকাউন্ট তৈরি করে দেওয়া
app.post('/api/admin/create-expert', async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      phone,
      designation,
      specialization,
      district,
      hotlineNumber,
      whatsappNumber,
      dutyHours,
    } = req.body;

    if (!name || !email || !password || !phone) {
      return res.status(400).json({ error: 'Name, email, password, and phone are required.' });
    }

    const existing = await User.findOne({ email: email.toLowerCase().trim() });
    if (existing) {
      return res.status(400).json({ error: 'এই ইমেইল দিয়ে ইতিমধ্যে একটি অ্যাকাউন্ট খোলা আছে।' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    const newExpert = new User({
      name: name.trim(),
      email: email.toLowerCase().trim(),
      password: hashedPassword,
      phone: phone.trim(),
      role: 'expert',
      designation: designation || 'উপজেলা কৃষি কর্মকর্তা',
      specialization: specialization || 'ফসল রোগতত্ত্ব ও সার ব্যবস্থাপনা',
      district: district || 'Khulna',
      hotlineNumber: hotlineNumber || phone.trim(),
      whatsappNumber: whatsappNumber || phone.trim(),
      dutyHours: dutyHours || 'সকাল ৯:০০ - বিকাল ৫:০০',
      isAvailable: true,
      badgeTitle: 'Verified Expert 👨‍🌾',
    });

    await newExpert.save();
    const expertObj = newExpert.toObject();
    delete expertObj.password;

    res.status(201).json({
      message: 'নতুন কৃষি বিশেষজ্ঞের অ্যাকাউন্ট সফলভাবে তৈরি হয়েছে!',
      expert: expertObj,
    });
  } catch (err) {
    console.error('Create Expert Error:', err);
    res.status(500).json({ error: 'Failed to create expert account' });
  }
});

// ----------------------------------------------------
// 👨‍🌾 FARMER VIEW: নিয়োগপ্রাপ্ত কৃষি বিশেষজ্ঞদের তালিকা
// ----------------------------------------------------
app.get('/api/experts', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const currentUser = await User.findById(userId);
    const farmerDistrict = (currentUser?.district || '').trim().toLowerCase();

    let experts = await User.find({ role: 'expert' })
      .select('-password')
      .sort({ isAvailable: -1, resolvedIssuesCount: -1 })
      .lean();

    if (farmerDistrict) {
      const localExperts = experts.filter((e) => (e.district || '').trim().toLowerCase() === farmerDistrict);
      const otherExperts = experts.filter((e) => (e.district || '').trim().toLowerCase() !== farmerDistrict);
      experts = [...localExperts, ...otherExperts];
    }

    res.status(200).json(experts);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch experts' });
  }
});

// ----------------------------------------------------
// ২. বিশেষজ্ঞের ড্যাশবোর্ড
// ----------------------------------------------------
app.get('/api/expert/dashboard', authenticate, async (req, res) => {
  try {
    const expertId = req.user.id || req.user._id;
    const expert = await User.findById(expertId).select('-password');

    const pendingQuery = {
      status: 'Pending_Expert',
      $or: [{ assignedExpert: expertId }, { assignedExpert: null }],
    };

    const resolvedQuery = {
      status: 'Expert_Resolved',
      $or: [{ resolvedBy: expertId }, { assignedExpert: expertId }],
    };

    const populateConfig = {
      path: 'cropId',
      select: 'cropCategory cropType variety allocatedArea areaUnit seedQuantity seedUnit seedSource cultivationMethod currentStage sowingDate totalExpense farmId',
      populate: { path: 'farmId', select: 'name location landSize unit soilType ph' },
    };

    const [myPendingIssues, myResolvedIssues, unreadMessagesCount] = await Promise.all([
      CropIssue.find(pendingQuery)
        .populate('userId', 'name phone district village')
        .populate('assignedExpert', 'name designation district')
        .populate(populateConfig)
        .sort({ createdAt: -1 })
        .lean(),
      CropIssue.find(resolvedQuery)
        .populate('userId', 'name phone district village')
        .populate('resolvedBy', 'name designation district')
        .populate(populateConfig)
        .sort({ resolvedAt: -1, updatedAt: -1 })
        .lean(),
      Message.countDocuments({ receiverId: expertId, isRead: false }),
    ]);

    res.status(200).json({
      expert,
      pendingCount: myPendingIssues.length,
      myResolvedCount: Math.max(expert?.resolvedIssuesCount || 0, myResolvedIssues.length),
      unreadMessagesCount,
      pendingIssues: myPendingIssues,
      resolvedIssues: myResolvedIssues,
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to load expert dashboard' });
  }
});

app.put('/api/expert/profile', authenticate, async (req, res) => {
  try {
    const expertId = req.user.id || req.user._id;
    const {
      name,
      phone,
      newPassword,
      designation,
      specialization,
      hotlineNumber,
      whatsappNumber,
      dutyHours,
      isAvailable,
      district,
      bio,
    } = req.body;

    const updateData = {
      designation,
      specialization,
      hotlineNumber,
      whatsappNumber,
      dutyHours,
      isAvailable,
      district,
      bio,
      badgeTitle: 'Verified Expert 👨‍🌾',
    };

    if (name && name.trim()) updateData.name = name.trim();
    if (phone && phone.trim()) updateData.phone = phone.trim();
    if (newPassword && newPassword.trim().length >= 6) {
      updateData.password = await bcrypt.hash(newPassword.trim(), 10);
    }

    const updated = await User.findByIdAndUpdate(expertId, updateData, { new: true }).select('-password');
    res.status(200).json({ message: 'আপনার প্রোফাইল ও অ্যাকাউন্ট তথ্য সফলভাবে আপডেট হয়েছে!', user: updated });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update expert profile' });
  }
});

app.post('/api/expert/broadcast-alert', authenticate, async (req, res) => {
  try {
    const expertId = req.user.id || req.user._id;
    const { title, alertText, targetDistrict } = req.body;
    if (!alertText) return res.status(400).json({ error: 'সতর্কবার্তার বিবরণ লিখুন।' });

    const expert = await User.findById(expertId);
    const location = targetDistrict || expert?.district || 'সারাদেশ';

    const formattedPost = `🚨 কৃষি কর্মকর্তার জরুরি পরামর্শ (${location})\n📌 বিষয়: ${title || 'বিশেষ সতর্কবার্তা'}\n\n${alertText}\n\n— ${expert?.name || 'কৃষি বিশেষজ্ঞ'} (${expert?.designation || 'কৃষি কর্মকর্তা'})`;

    const newPost = new CommunityPost({
      userId: expertId,
      text: formattedPost,
      location,
    });

    await newPost.save();
    res.status(201).json({ message: 'জরুরি সতর্কবার্তা সব কৃষকের কাছে প্রকাশ করা হয়েছে!', post: newPost });
  } catch (err) {
    res.status(500).json({ error: 'Failed to broadcast alert' });
  }
});

// ----------------------------------------------------
// 💬 DIRECT IN-APP MESSAGING
// ----------------------------------------------------
app.get('/api/messages/conversations', authenticate, async (req, res) => {
  try {
    const myId = (req.user.id || req.user._id).toString();
    const messages = await Message.find({
      $or: [{ senderId: myId }, { receiverId: myId }],
    })
      .populate('senderId', 'name phone role designation district profilePicture isAvailable')
      .populate('receiverId', 'name phone role designation district profilePicture isAvailable')
      .sort({ createdAt: -1 })
      .lean();

    const conversationMap = new Map();

    for (const msg of messages) {
      if (!msg.senderId || !msg.receiverId) continue;
      const sId = msg.senderId._id.toString();
      const rId = msg.receiverId._id.toString();
      const partner = sId === myId ? msg.receiverId : msg.senderId;
      const partnerId = partner._id.toString();

      if (!conversationMap.has(partnerId)) {
        conversationMap.set(partnerId, {
          partner,
          lastMessage: msg.text,
          lastTime: msg.createdAt,
          unreadCount: 0,
        });
      }
      if (rId === myId && !msg.isRead) {
        conversationMap.get(partnerId).unreadCount += 1;
      }
    }

    res.status(200).json(Array.from(conversationMap.values()));
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch conversations' });
  }
});

app.get('/api/messages/:otherUserId', authenticate, async (req, res) => {
  try {
    const myId = req.user.id || req.user._id;
    const otherId = req.params.otherUserId;

    await Message.updateMany(
      { senderId: otherId, receiverId: myId, isRead: false },
      { $set: { isRead: true } }
    );

    const messages = await Message.find({
      $or: [
        { senderId: myId, receiverId: otherId },
        { senderId: otherId, receiverId: myId },
      ],
    })
      .sort({ createdAt: 1 })
      .lean();

    res.status(200).json(messages);
  } catch (err) {
    res.status(500).json({ error: 'Failed to load messages' });
  }
});

app.post('/api/messages/:otherUserId', authenticate, async (req, res) => {
  try {
    const myId = req.user.id || req.user._id;
    const otherId = req.params.otherUserId;
    const { text, imageBase64 } = req.body;

    if (!text || !text.trim()) {
      return res.status(400).json({ error: 'মেসেজ খালি রাখা যাবে না।' });
    }

    const newMsg = new Message({
      senderId: myId,
      receiverId: otherId,
      text: text.trim(),
      imageBase64: imageBase64 || null,
    });

    await newMsg.save();
    res.status(201).json(newMsg);
  } catch (err) {
    res.status(500).json({ error: 'Failed to send message' });
  }
});

app.get('/api/admin/crops', async (req, res) => {
  try {
    const crops = await Crop.find()
      .populate('userId', 'name email phone')
      .populate('farmId', 'name location')
      .sort({ createdAt: -1 });
    res.status(200).json(crops);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch crops' });
  }
});

app.get('/api/admin/farms', async (req, res) => {
  try {
    const farms = await Farm.find()
      .populate('userId', 'name email phone district')
      .sort({ createdAt: -1 });
    res.status(200).json(farms);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch farms' });
  }
});

app.get('/api/admin/activities', async (req, res) => {
  try {
    const tasks = await Task.find()
      .populate('userId', 'name email')
      .populate('cropId', 'cropType')
      .sort({ scheduledDate: -1 });
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const modifiedTasks = tasks.map((task) => {
      let displayStatus = task.status;
      if (displayStatus === 'Pending' && task.scheduledDate) {
        const taskDate = new Date(task.scheduledDate);
        taskDate.setHours(0, 0, 0, 0);
        if (taskDate > today) displayStatus = 'Upcoming';
      }
      return { ...task.toObject(), status: displayStatus };
    });
    res.status(200).json(modifiedTasks);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch activities' });
  }
});

// ----------------------------------------------------
// 🌧️ MULTI-LOCATION & RED ALERT WEATHER API
// ----------------------------------------------------
app.get('/api/weather', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const user = await User.findById(userId);
    const farms = await Farm.find({ userId: userId, status: 'active' });

    const locations = new Set();
    if (user.district) locations.add(user.district);
    else locations.add('Khulna');
    farms.forEach((f) => {
      if (f.location) locations.add(f.location);
    });

    const weatherData = [];

    for (let loc of locations) {
      try {
        const forecastUrl = `https://api.openweathermap.org/data/2.5/forecast?q=${loc},BD&units=metric&appid=${process.env.WEATHER_API_KEY}`;
        const response = await axios.get(forecastUrl);
        const list = response.data.list;
        const current = list[0];

        const temp = Math.round(current.main.temp);
        const conditionCode = current.weather[0].id;
        const conditionMain = current.weather[0].main;

        let conditionBn = 'স্বাভাবিক';
        if (conditionCode >= 200 && conditionCode < 300) conditionBn = 'বজ্রঝড়';
        else if (conditionCode >= 300 && conditionCode < 400) conditionBn = 'গুঁড়ি গুঁড়ি বৃষ্টি';
        else if (conditionCode >= 500 && conditionCode < 600) conditionBn = 'বৃষ্টিপাত';
        else if (conditionCode >= 600 && conditionCode < 700) conditionBn = 'শিলাবৃষ্টি/তুষার';
        else if (conditionCode >= 700 && conditionCode < 800) conditionBn = 'কুয়াশা/ধোঁয়াশা';
        else if (conditionCode === 800) conditionBn = 'রৌদ্রোজ্জ্বল (পরিষ্কার)';
        else if (conditionCode > 800) conditionBn = 'মেঘলা';

        const next3Days = list.slice(0, 24);
        let hasAlert = false;
        let alertMessage = '';

        const willStorm = next3Days.some((f) => f.weather[0].id >= 200 && f.weather[0].id < 300);
        const willHeavyRain = next3Days.some(
          (f) => f.weather[0].id === 502 || f.weather[0].id === 503 || f.weather[0].id === 504
        );
        const willHail = next3Days.some(
          (f) =>
            f.weather[0].id === 602 ||
            f.weather[0].id === 622 ||
            f.weather[0].id === 906 ||
            (f.weather[0].id >= 600 && f.weather[0].id < 700)
        );

        if (willStorm) {
          hasAlert = true;
          alertMessage = `🚨 জরুরি সতর্কতা: আগামী ৩ দিনের মধ্যে '${loc}' এলাকায় প্রবল বজ্রঝড় ও কালবৈশাখীর সম্ভাবনা রয়েছে! ফসল রক্ষায় দ্রুত ব্যবস্থা নিন।`;
        } else if (willHail) {
          hasAlert = true;
          alertMessage = `🚨 জরুরি সতর্কতা: আগামী ৩ দিনের মধ্যে '${loc}' এলাকায় শিলাবৃষ্টির সম্ভাবনা রয়েছে!`;
        } else if (willHeavyRain) {
          hasAlert = true;
          alertMessage = `🚨 জরুরি সতর্কতা: আগামী ৩ দিনের মধ্যে '${loc}' এলাকায় অতিভারী বৃষ্টির সম্ভাবনা রয়েছে! জমির পানি নিষ্কাশন ব্যবস্থা সচল রাখুন।`;
        }

        weatherData.push({
          location: loc,
          temp: temp,
          humidity: current.main.humidity,
          windSpeed: (current.wind.speed * 3.6).toFixed(1),
          condition: conditionMain,
          conditionBn: conditionBn,
          hasAlert: hasAlert,
          alertMessage: alertMessage,
          isHome: loc === user.district,
        });
      } catch (err) {
        console.log(`⚠️ Failed to fetch weather for ${loc}`);
      }
    }

    res.status(200).json(weatherData);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch weather' });
  }
});

app.put('/api/crops/:id', authenticate, async (req, res) => {
  try {
    const updatedCrop = await Crop.findByIdAndUpdate(
      req.params.id,
      {
        cropType: req.body.cropType,
        variety: req.body.variety,
        cultivationMethod: req.body.cultivationMethod,
        currentStage: req.body.currentStage,
        status: req.body.status,
      },
      { new: true }
    );
    res.status(200).json({ message: 'Crop updated!', crop: updatedCrop });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update crop' });
  }
});

app.delete('/api/crops/:id', authenticate, async (req, res) => {
  try {
    await Crop.findByIdAndDelete(req.params.id);
    await Task.deleteMany({ cropId: req.params.id });
    await CropIssue.deleteMany({ cropId: req.params.id });
    res.status(200).json({ message: 'Crop deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete crop' });
  }
});

app.put('/api/farms/:id', authenticate, async (req, res) => {
  try {
    const updatedFarm = await Farm.findByIdAndUpdate(
      req.params.id,
      {
        name: req.body.name,
        landSize: req.body.landSize,
        location: req.body.location,
        soilType: req.body.soilType,
        ph: req.body.ph,
      },
      { new: true }
    );
    res.status(200).json({ message: 'Farm updated!', farm: updatedFarm });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update farm' });
  }
});

app.delete('/api/farms/:id', authenticate, async (req, res) => {
  try {
    await Farm.findByIdAndDelete(req.params.id);
    await Crop.deleteMany({ farmId: req.params.id });
    await Task.deleteMany({ farmId: req.params.id });
    await CropIssue.deleteMany({ farmId: req.params.id });
    res.status(200).json({ message: 'Farm deleted' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to delete farm' });
  }
});

// ----------------------------------------------------
// 🌟 COMMUNITY FEED APIs
// ----------------------------------------------------
app.post('/api/community/posts', authenticate, async (req, res) => {
  try {
    const { text, imageBase64, cropIssueId } = req.body;
    const userId = req.user.id || req.user._id;

    if (!text) {
      return res.status(400).json({ error: 'Post text is required.' });
    }

    const user = await User.findById(userId);
    const location = user?.district || 'Bangladesh';

    const newPost = new CommunityPost({
      userId,
      text,
      imageBase64: imageBase64 || null,
      cropIssueId: cropIssueId || null,
      location,
    });

    await newPost.save();
    res.status(201).json({ message: 'Post created successfully!', post: newPost });
  } catch (err) {
    res.status(500).json({ error: 'Failed to create post.' });
  }
});

app.delete('/api/community/posts/:id', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const post = await CommunityPost.findById(req.params.id);

    if (!post) return res.status(404).json({ error: 'Post not found.' });

    if (post.userId.toString() !== userId.toString()) {
      return res.status(403).json({ error: 'Unauthorized to delete this post.' });
    }

    await CommunityPost.findByIdAndDelete(req.params.id);
    res.status(200).json({ message: 'Post deleted successfully!' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete post.' });
  }
});

app.put('/api/community/posts/:id', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const { text } = req.body;

    const post = await CommunityPost.findById(req.params.id);
    if (!post) return res.status(404).json({ error: 'Post not found.' });

    if (post.userId.toString() !== userId.toString()) {
      return res.status(403).json({ error: 'Unauthorized to edit this post.' });
    }

    post.text = text || post.text;
    await post.save();

    res.status(200).json({ message: 'Post updated successfully!', post });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update post.' });
  }
});

app.post('/api/community/share-issue', authenticate, async (req, res) => {
  try {
    const { cropIssueId, solutionType } = req.body;
    const userId = req.user.id || req.user._id;

    const issue = await CropIssue.findById(cropIssueId);
    if (!issue) return res.status(404).json({ error: 'Issue not found.' });

    const user = await User.findById(userId);
    const location = user?.district || 'Bangladesh';

    let solutionText = '';
    if (solutionType === 'AI' && issue.aiAdvice) {
      solutionText = `📋 প্রাথমিক সমাধান:\n${issue.aiAdvice}`;
    } else if (solutionType === 'Expert' && issue.expertReply) {
      solutionText = `👨‍🌾 বিশেষজ্ঞের সমাধান:\n${issue.expertReply}`;
    } else {
      return res.status(400).json({ error: 'No valid solution found to share.' });
    }

    const postText = `📍 এলাকা: ${location}\n\n🚨 ফসলের সমস্যা:\n"${issue.issueText}"\n\n-------------------------\n✅ পরীক্ষিত সমাধান:\n${solutionText}`;

    const newPost = new CommunityPost({
      userId,
      cropIssueId: issue._id,
      text: postText,
      imageBase64: issue.imageBase64 || null,
      location,
    });

    await newPost.save();
    res.status(201).json({ message: 'কমিউনিটিতে সফলভাবে শেয়ার করা হয়েছে!', post: newPost });
  } catch (err) {
    res.status(500).json({ error: 'Failed to share to community.' });
  }
});

app.get('/api/community/posts', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const currentUser = await User.findById(userId);
    const userDistrict = currentUser?.district || '';

    let allPosts = await CommunityPost.find()
      .populate('userId', 'name profilePicture district isTopFarmer badgeTitle')
      .populate('comments.userId', 'name profilePicture isTopFarmer badgeTitle')
      .sort({ createdAt: -1 })
      .lean();

    if (userDistrict) {
      const fifteenDaysAgo = new Date();
      fifteenDaysAgo.setDate(fifteenDaysAgo.getDate() - 15);

      const recentLocalPosts = allPosts.filter(
        (p) => p.location === userDistrict && new Date(p.createdAt) >= fifteenDaysAgo
      );
      const otherPosts = allPosts.filter(
        (p) => !(p.location === userDistrict && new Date(p.createdAt) >= fifteenDaysAgo)
      );

      allPosts = [...recentLocalPosts, ...otherPosts];
    }

    res.status(200).json(allPosts);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch posts.' });
  }
});

app.put('/api/community/posts/:id/like', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const post = await CommunityPost.findById(req.params.id);

    if (!post) return res.status(404).json({ error: 'Post not found.' });

    const hasLiked = post.likes.includes(userId);
    if (hasLiked) {
      post.likes.pull(userId);
    } else {
      post.likes.push(userId);
    }

    await post.save();
    res.status(200).json({ message: hasLiked ? 'Unliked' : 'Liked', likesCount: post.likes.length });
  } catch (err) {
    res.status(500).json({ error: 'Failed to like/unlike post.' });
  }
});

app.post('/api/community/posts/:id/comment', authenticate, async (req, res) => {
  try {
    const { text } = req.body;
    const userId = req.user.id || req.user._id;

    if (!text) return res.status(400).json({ error: 'Comment text is required.' });

    const post = await CommunityPost.findById(req.params.id);
    if (!post) return res.status(404).json({ error: 'Post not found.' });

    post.comments.push({ userId, text });
    await post.save();

    res.status(201).json({ message: 'Comment added!', post });
  } catch (err) {
    res.status(500).json({ error: 'Failed to add comment.' });
  }
});

app.delete('/api/community/posts/:postId/comment/:commentId', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const { postId, commentId } = req.params;

    const post = await CommunityPost.findById(postId);
    if (!post) return res.status(404).json({ error: 'Post not found.' });

    const comment = post.comments.id(commentId);
    if (!comment) return res.status(404).json({ error: 'Comment not found.' });

    if (comment.userId.toString() !== userId.toString()) {
      return res.status(403).json({ error: 'Unauthorized to delete this comment.' });
    }

    comment.deleteOne();
    await post.save();

    res.status(200).json({ message: 'Comment deleted successfully!', post });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete comment.' });
  }
});

app.put('/api/community/posts/:postId/comment/:commentId', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const { postId, commentId } = req.params;
    const { text } = req.body;

    const post = await CommunityPost.findById(postId);
    if (!post) return res.status(404).json({ error: 'Post not found.' });

    const comment = post.comments.id(commentId);
    if (!comment) return res.status(404).json({ error: 'NotFound' });

    if (comment.userId.toString() !== userId.toString()) {
      return res.status(403).json({ error: 'Unauthorized.' });
    }

    comment.text = text || comment.text;
    await post.save();

    res.status(200).json({ message: 'Comment updated successfully!', post });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update comment.' });
  }
});

if (!MONGO_URI) {
  console.error('❌ Error: MONGO_URI is not defined in .env file!');
  process.exit(1);
}

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB Connected Successfully!');
    app.listen(PORT, () => console.log(`🚀 Server running securely on http://localhost:${PORT}`));
  })
  .catch((err) => console.error('❌ Database connection error:', err.message));