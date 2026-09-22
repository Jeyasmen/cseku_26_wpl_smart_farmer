const CropIssue = require('./src/CropIssue');
const cron = require('node-cron');
const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
const axios = require('axios');
const { GoogleGenerativeAI } = require('@google/generative-ai'); 
require('dotenv').config();

const { signup, signin } = require('./src/auth');
const { authenticate } = require('./src/authMiddleware');
const User = require('./src/User');
const Farm = require('./src/Farm');
const Crop = require('./src/Crop');
const Task = require('./src/Task');
const CommunityPost = require('./src/CommunityPost'); // 🚀 নতুন মডেল ইমপোর্ট

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

// 2. Health check
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server is healthy and running' });
});

// 3. Authentication
app.post('/api/auth/signup', signup);
app.post('/api/auth/signin', signin);

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
    await CommunityPost.deleteMany({ userId }); // ইউজারের সব পোস্ট ডিলিট
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
    const { name, landSize, location, soilType, ph, description } = req.body;
    const userId = req.user.id || req.user._id;
    const newFarm = new Farm({
      userId, name, landSize: Number(landSize), location: location || '',
      soilType: soilType || 'Loamy', ph: ph ? Number(ph) : null, description: description || '',
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
      Task.find({ userId, isUrgent: true, status: 'Pending' }).populate('farmId', 'name')
    ]);
    res.status(200).json({ activeFarmsCount, activeCropsCount: activeCrops.length, urgentTasksCount: urgentTasks.length, urgentTasks, activeCrops });
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
    const userFarms = await Farm.find({ userId: userId });

    let farmsContext = "The farmer has not registered any farms yet.";
    if (userFarms && userFarms.length > 0) {
      farmsContext = "The farmer currently owns the following farms in the database:\n" + 
        userFarms.map(f => `- Farm Name: "${f.name}", Location: ${f.location}, Soil Type: ${f.soilType}, pH: ${f.ph}, Land Size: ${f.landSize} ${f.unit}`).join("\n");
    }

    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-3.5-flash-lite" });

    let historyText = "";
    if (history && history.length > 0) {
      historyText = "Previous Conversation:\n" + history.map(msg => 
        `${msg.sender === 'user' ? 'Farmer' : 'AI'}: ${msg.text}`
      ).join("\n") + "\n\n";
    }

    const prompt = `
      You are an Elite Agricultural Expert and Crop Doctor in Bangladesh.
      
      [USER'S ACTUAL FARM DATA FROM DATABASE]
      ${farmsContext}
      
      CRITICAL RULES:
      1. YOUR MEMORY: When the user asks about "my farm", "east field", etc., check the database context first. Do NOT guess.
      2. FARM QUESTIONS ARE VALID: Questions about farm size, soil, or location are valid.
      3. STRICT BOUNDARY: ONLY refuse unrelated topics (like sports, politics).
      4. Keep response natural and in simple Bengali.
      
      ${historyText}
      Farmer's New Question: "${question}"
    `;

    const result = await model.generateContent(prompt);
    res.status(200).json({ answer: result.response.text().trim() });
  } catch (error) {
    res.status(500).json({ error: 'AI is temporarily busy.' });
  }
});

// ----------------------------------------------------
// 6. MASTER CROP PLAN GENERATOR (At Crop Registration)
// ----------------------------------------------------
async function generateAITasks(cropType, variety, cultivationMethod, cropId, farmId, userId, startDate) {
  try {
    const apiKey = process.env.GEMINI_API_KEY;
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-3.5-flash-lite" });

    const prompt = `
      The farmer is planting "${cropType}" (Variety: ${variety || 'Local'}, Method: ${cultivationMethod}).
      Generate a professional master timeline of 5 to 7 crucial farming activities from planting to harvesting.
      
      CRITICAL RULE FOR LONG-TERM CROPS (Orchards/Fruit Trees):
      If the crop is a long-term tree like Malta, Orange, Mango, or Guava, the tasks should span over 1-2 years (e.g., sapling care, pruning, pre-monsoon fertilizing). Do NOT suggest harvesting in 3 months for these!

      Return strictly a JSON array. Format:
      [
        { "title": "...", "activityType": "Watering|Fertilizing|Maintenance|Pesticide|Harvesting|Monitoring", "daysAfterSowing": int, "isUrgent": boolean }
      ]
    `;

    const result = await model.generateContent(prompt);
    const aiResponse = result.response.text().trim();
    const jsonMatch = aiResponse.match(/\[[\s\S]*\]/);
    const taskTemplates = JSON.parse(jsonMatch[0]);

    return taskTemplates.map(t => ({
      userId, farmId, cropId, title: t.title, activityType: t.activityType,
      scheduledDate: new Date(startDate.getTime() + t.daysAfterSowing * 24 * 60 * 60 * 1000),
      isUrgent: t.isUrgent, status: 'Pending'
    }));
  } catch (error) {
    return [
      { userId, farmId, cropId, title: `${cropType}: প্রাথমিক সেচ`, activityType: 'Watering', scheduledDate: new Date(startDate.getTime() + 2 * 86400000), isUrgent: true, status: 'Pending' },
      { userId, farmId, cropId, title: `${cropType}: সুষম সার প্রয়োগ`, activityType: 'Fertilizing', scheduledDate: new Date(startDate.getTime() + 15 * 86400000), isUrgent: false, status: 'Pending' },
    ];
  }
}

// ----------------------------------------------------
// 🧠 THE CENTRAL AI BRAIN (Helper Function for Auto & Manual Optimize)
// ----------------------------------------------------
async function optimizeCropTasksWithAI(cropId) {
  const crop = await Crop.findById(cropId).populate('farmId');
  if (!crop) throw new Error("Crop not found");

  const todayDateObj = new Date();
  todayDateObj.setHours(0, 0, 0, 0);
  const sowingDate = new Date(crop.sowingDate);
  const cropAgeDays = Math.floor((new Date() - sowingDate) / (1000 * 60 * 60 * 24));

  // History Check
  const completedTasks = await Task.find({ cropId: crop._id, status: 'Completed' }).sort({ scheduledDate: -1 }).limit(12);
  let taskHistoryText = "No tasks completed yet.";
  if (completedTasks.length > 0) {
    taskHistoryText = completedTasks.map(t => `- [${t.activityType}] ${t.title} (Done on: ${t.scheduledDate.toISOString().split('T')[0]})`).join("\n");
  }

  // Pending Tasks
  const pendingTasks = await Task.find({ cropId: crop._id, status: 'Pending' });
  let pendingTasksText = "No pending tasks.";
  if (pendingTasks.length > 0) {
    pendingTasksText = pendingTasks.map(t => `ID: ${t._id}, Title: "${t.title}", Date: ${t.scheduledDate.toISOString().split('T')[0]}, Type: ${t.activityType}`).join("\n");
  }

  // Weather Check
  const location = crop.farmId?.location || 'Khulna';
  let weatherSummary = "Normal weather";
  try {
    const weatherUrl = `https://api.openweathermap.org/data/2.5/forecast?q=${location},BD&units=metric&appid=${process.env.WEATHER_API_KEY}`;
    const weatherRes = await axios.get(weatherUrl);
    const forecasts = weatherRes.data.list.slice(0, 24); // Next 3 days
    const willRain = forecasts.some(f => f.weather[0].id >= 500 && f.weather[0].id < 600);
    const willStorm = forecasts.some(f => f.weather[0].id >= 200 && f.weather[0].id < 300);
    
    if (willStorm) weatherSummary = "Severe storm expected in next 3 days!";
    else if (willRain) weatherSummary = "Rain expected in next 3 days.";
    else weatherSummary = "Sunny and clear weather for next 3 days.";
  } catch (err) {
    console.log(`⚠️ Weather error for ${location}`);
  }

  // 🚀 The Master Prompt (Real-Life Farming Logic)
  const prompt = `
    You are an Elite Agricultural AI guiding a farmer in Bangladesh to MAXIMIZE YIELD and PREVENT CROP LOSS.
    Today's Date: ${new Date().toISOString().split('T')[0]}
    Crop: "${crop.cropType}" (Variety: ${crop.variety || 'Local'}). Age: ${cropAgeDays} days.
    Weather Forecast (${location}): ${weatherSummary}.

    [COMPLETED TASKS HISTORY (CRITICAL SEQUENCE)]
    ${taskHistoryText}

    [PENDING & OVERDUE TASKS]
    ${pendingTasksText}

    YOUR MISSION: Guide the farmer perfectly by analyzing Real-Life scenarios, Crop Age, and Weather.
    
    🚨 REAL-LIFE SCENARIO HANDLING RULES (MUST FOLLOW):
    1. WATERING vs RAIN (Nature's Job): If a "Watering" (সেচ) task is pending, but it is raining today or rained yesterday, DO NOT ask the farmer to water. Action MUST be "Delete" (Reason: বৃষ্টির কারণে সেচের প্রয়োজন নেই).
    2. FERTILIZER/PESTICIDE WASHOUT (সার ধুয়ে যাওয়া): NEVER schedule or keep "Fertilizing" or "Pesticide" tasks on a rainy or stormy day. Rain will wash the chemicals away, wasting the farmer's money.
    3. URGENT vs CONTINUOUS BAD WEATHER: If a fertilizer/pesticide is URGENT (due to critical crop age) but the next 1-2 days have heavy rain, DO NOT just blindly delay by 2 days. Analyze the weather forecast and Action "Reschedule" to the NEAREST PERFECTLY CLEAR/SUNNY DAY. 
    4. AFTER-RAIN MONITORING: If a storm or heavy rain just passed, generate a new task for Today to monitor field condition (e.g., "বৃষ্টির পর জমিতে পানি জমে আছে কিনা এবং পাতায় পচন ধরেছে কিনা চেক করুন").
    5. SEQUENCE AWARENESS: Check [COMPLETED TASKS HISTORY]. If fertilizer was given 3 days ago, DO NOT give another fertilizer task today.

    STEP 1: CLEANUP PENDING TASKS
    - Action "Delete": If task is no longer needed (e.g., watering during rain).
    - Action "Reschedule": Move to the most logical future date (offsetDays: 1, 2, or 3) based on the weather rules above.
    - Action "Keep": If the task is perfectly fine for today.

    STEP 2: GENERATE NEW TASKS (ONLY IF ABSOLUTELY NECESSARY)
    - If the farmer just needs to wait and let the crop grow, DO NOT invent random tasks. Return empty array for newTasks.
    - Only give tasks that are vital for today or the next 3 days.

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
          "howToGuide": "Detailed instruction and reason in Bengali."
        }
      ]
    }
  `;

  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  const model = genAI.getGenerativeModel({ model: "gemini-3.5-flash-lite" });
  const result = await model.generateContent(prompt);
  let aiResponse = result.response.text().trim();
  const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);

  let updatedCount = 0, deletedCount = 0, newCreatedCount = 0;

  if (jsonMatch) {
    const aiData = JSON.parse(jsonMatch[0]);

    // Apply Cleanups & Reschedules
    if (aiData.pendingUpdates && Array.isArray(aiData.pendingUpdates)) {
      for (let update of aiData.pendingUpdates) {
        const task = pendingTasks.find(t => t._id.toString() === update.id);
        if (!task) continue;

        if (update.action === 'Delete') {
          await Task.findByIdAndDelete(task._id);
          deletedCount++;
        } else if (update.action === 'Reschedule') {
          const newDate = new Date();
          newDate.setDate(newDate.getDate() + (update.newDateOffsetDays || 0));
          task.scheduledDate = newDate;
          if (!task.title.includes('[AI Update]')) task.title = `${task.title} [AI Update]`;
          await task.save();
          updatedCount++;
        }
      }
    }

    // Create New Intelligent Tasks
    if (aiData.newTasks && Array.isArray(aiData.newTasks)) {
      for (let nTask of aiData.newTasks) {
        if (!nTask.title || nTask.title.trim() === '') continue; // Skip empty tasks
        
        const newDate = new Date();
        newDate.setDate(newDate.getDate() + (nTask.offsetDays || 0));
        
        const newTask = new Task({
          userId: crop.userId, farmId: crop.farmId._id, cropId: crop._id,
          title: nTask.title, activityType: nTask.activityType, description: nTask.howToGuide,
          scheduledDate: newDate, isUrgent: nTask.isUrgent || false, status: 'Pending'
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
      message: `AI Optimizer Success! ${metrics.deletedCount}টি বাতিল কাজ মুছে ফেলা হয়েছে, ${metrics.updatedCount}টি রিশিডিউল করা হয়েছে এবং ${metrics.newCreatedCount}টি নতুন গাইড যুক্ত করা হয়েছে।` 
    });
  } catch (err) {
    console.error("Manual Optimizer Error:", err);
    res.status(500).json({ error: 'Failed to connect to AI Brain.' });
  }
});

// ----------------------------------------------------
// 12. DAILY AI CRON JOB (Autopilot Mode)
// ----------------------------------------------------
cron.schedule('0 6 * * *', async () => {
  try {
    console.log("⏰ [Cron] Daily AI Agronomist is waking up...");
    const activeCrops = await Crop.find({ status: 'In Progress' });
    
    if (activeCrops.length === 0) return console.log("✅ No active crops to check.");

    for (let crop of activeCrops) {
      try {
        await optimizeCropTasksWithAI(crop._id);
        console.log(`✅ [Autopilot] ${crop.cropType} এর শিডিউল অটো-আপডেট করা হয়েছে।`);
      } catch (err) {
        console.log(`⚠️ Auto-optimize failed for ${crop._id}: ${err.message}`);
      }
    }
  } catch (error) {
    console.error("❌ Cron Job Master Error:", error.message);
  }
});

// ----------------------------------------------------
// ADMIN PANEL, ASK AI & OTHERS
// ----------------------------------------------------

app.get('/api/admin/issues/pending', authenticate, async (req, res) => {
  try {
    const pendingIssues = await CropIssue.find({ status: 'Pending_Expert' }).populate('userId', 'name phone').populate({ path: 'cropId', select: 'cropType variety currentStage sowingDate farmId', populate: { path: 'farmId', select: 'name location soilType ph' } }).sort({ createdAt: -1 });
    res.status(200).json({ issues: pendingIssues });
  } catch (error) { res.status(500).json({ error: 'Failed to fetch issues.' }); }
});

app.put('/api/admin/issues/:issueId/reply', authenticate, async (req, res) => {
  try {
    const { issueId } = req.params;
    const { expertReply } = req.body;
    if (!expertReply) return res.status(400).json({ error: 'Reply message is required.' });
    const updatedIssue = await CropIssue.findByIdAndUpdate(issueId, { expertReply: expertReply, status: 'Expert_Resolved' }, { new: true });
    if (!updatedIssue) return res.status(404).json({ error: 'Issue not found' });
    res.status(200).json({ message: '✅ কৃষকের কাছে সফলভাবে আপনার পরামর্শ পাঠানো হয়েছে!' });
  } catch (error) { res.status(500).json({ error: 'Failed to send reply.' }); }
});

app.post('/api/crops/:id/issues/ask-ai', authenticate, async (req, res) => {
  try {
    const { issueText, imageBase64 } = req.body;
    const cropId = req.params.id;
    const crop = await Crop.findById(cropId).populate('farmId');
    if (!crop) return res.status(404).json({ error: 'Crop not found' });

    const userId = (req.user && (req.user.id || req.user.userId || req.user._id)) || crop.userId;
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: "gemini-3.5-flash-lite" });

    const prompt = `
      You are an Elite Agricultural Expert and Crop Doctor in Bangladesh. 
      Crop: ${crop.cropType}. Farmer says: "${issueText}"
      CRITICAL RULES:
      1. ONLY answer agriculture/farming questions. Refuse others in Bengali.
      2. Give direct, accurate, simple Bengali solutions. Mention specific medicines/fertilizers if needed.
    `;

    let aiResponseText = "";
    if (imageBase64) {
      const imageParts = [{ inlineData: { data: imageBase64, mimeType: "image/jpeg" } }];
      const result = await model.generateContent([prompt, ...imageParts]);
      aiResponseText = result.response.text().trim();
    } else {
      const result = await model.generateContent(prompt);
      aiResponseText = result.response.text().trim();
    }

    const newIssue = new CropIssue({ userId, cropId, issueText, imageBase64, aiAdvice: aiResponseText, status: 'AI_Resolved' });
    await newIssue.save();

    res.status(200).json({ issueId: newIssue._id, answer: aiResponseText, message: 'Success' });
  } catch (error) { res.status(500).json({ error: 'AI is temporarily unavailable.' }); }
});

app.put('/api/issues/:issueId/ask-expert', authenticate, async (req, res) => {
  try {
    const updatedIssue = await CropIssue.findByIdAndUpdate(req.params.issueId, { needsExpert: true, status: 'Pending_Expert' }, { new: true });
    if (!updatedIssue) return res.status(404).json({ error: 'Issue not found' });
    res.status(200).json({ message: 'আপনার সমস্যাটি বিশেষজ্ঞের কাছে পাঠানো হয়েছে!' });
  } catch (error) { res.status(500).json({ error: 'Failed to send to expert.' }); }
});

app.post('/api/crops', authenticate, async (req, res) => {
  try {
    const { farmId, cropType, variety, sowingDate, cultivationMethod, description } = req.body;
    const userId = req.user.id || req.user._id;

    if (!farmId || !cropType || !sowingDate) return res.status(400).json({ error: 'Farm, crop type, and sowing date required.' });

    const startDate = new Date(sowingDate);

    // 🚀 AI-কে দিয়ে টাস্ক তৈরি করানো
    // AI Harvest Date জেনারেট করবে
    const aiGeneratedTasks = await generateAITasks(cropType, variety, cultivationMethod, null, farmId, userId, startDate);

    let harvestDate = new Date(startDate);
    harvestDate.setDate(harvestDate.getDate() + 90); // Default to 90 days

    // Find the harvesting task generated by AI to set expected harvest date accurately
    const harvestingTask = aiGeneratedTasks.find(t => t.activityType === 'Harvesting');
    if (harvestingTask) {
        harvestDate = new Date(harvestingTask.scheduledDate);
    }

    const newCrop = new Crop({
      userId, farmId, cropType, variety: variety || '', cultivationMethod: cultivationMethod || 'Open Field',
      description: description || '', sowingDate: startDate, expectedHarvestDate: harvestDate, currentStage: 'Germination',
    });
    
    await newCrop.save();

    // Update cropId in generated tasks before saving
    const tasksToSave = aiGeneratedTasks.map(t => ({...t, cropId: newCrop._id}));
    await Task.insertMany(tasksToSave);

    res.status(201).json({ message: 'Crop added and Master Plan generated!', crop: newCrop });
  } catch (err) { 
    console.error('Error adding crop:', err);
    res.status(500).json({ error: 'Failed to add crop' }); 
  }
});

app.get('/api/crops/my', authenticate, async (req, res) => {
  try {
    const crops = await Crop.find({ userId: req.user.id || req.user._id }).populate('farmId', 'name location').sort({ createdAt: -1 });
    res.status(200).json(crops);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch crops' }); }
});

app.get('/api/crops/:id/details', authenticate, async (req, res) => {
  try {
    const crop = await Crop.findById(req.params.id).populate('farmId', 'name');
    if (!crop) return res.status(404).json({ error: 'Crop not found' });
    const tasks = await Task.find({ cropId: req.params.id }).sort({ scheduledDate: 1 });
    res.status(200).json({ crop, tasks });
  } catch (err) { res.status(500).json({ error: 'Failed to fetch crop details' }); }
});

app.post('/api/crops/:id/expenses', authenticate, async (req, res) => {
  try {
    const crop = await Crop.findById(req.params.id);
    if (!crop) return res.status(404).json({ error: 'Crop not found' });
    const expAmt = Number(req.body.amount);
    crop.expenses.unshift({ title: req.body.title, amount: expAmt });
    crop.totalExpense += expAmt;
    await crop.save();
    res.status(200).json(crop);
  } catch (err) { res.status(500).json({ error: 'Failed to add expense' }); }
});

app.post('/api/crops/:id/notes', authenticate, async (req, res) => {
  try {
    const crop = await Crop.findById(req.params.id);
    if (!crop) return res.status(404).json({ error: 'Crop not found' });
    crop.diaryNotes.unshift({ note: req.body.note });
    await crop.save();
    res.status(200).json(crop);
  } catch (err) { res.status(500).json({ error: 'Failed to add note' }); }
});

app.get('/api/tasks/my', authenticate, async (req, res) => {
  try {
    const tasks = await Task.find({ userId: req.user.id || req.user._id }).populate('cropId', 'cropType').populate('farmId', 'name').sort({ scheduledDate: 1 });
    res.status(200).json(tasks);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch tasks' }); }
});

app.put('/api/tasks/:id/complete', authenticate, async (req, res) => {
  try {
    const task = await Task.findByIdAndUpdate(req.params.id, { status: 'Completed' }, { new: true });
    res.status(200).json({ message: 'Task marked as completed', task });
  } catch (err) { res.status(500).json({ error: 'Failed to update task' }); }
});

app.get('/api/admin/users', async (req, res) => {
  try {
    const users = await User.find().select('-password').sort({ createdAt: -1 });
    res.status(200).json(users);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch users' }); }
});

app.delete('/api/admin/users/:id', async (req, res) => {
  try { await User.findByIdAndDelete(req.params.id); res.status(200).json({ message: 'User deleted' }); } catch (err) { res.status(500).json({ error: 'Failed to delete user' }); }
});

app.put('/api/admin/users/:id/role', async (req, res) => {
  try {
    const updatedUser = await User.findByIdAndUpdate(req.params.id, { role: req.body.role }, { new: true }).select('-password');
    res.status(200).json({ message: 'Role updated', user: updatedUser });
  } catch (err) { res.status(500).json({ error: 'Failed to update role' }); }
});

app.get('/api/admin/crops', async (req, res) => {
  try {
    const crops = await Crop.find().populate('userId', 'name email phone').populate('farmId', 'name location').sort({ createdAt: -1 });
    res.status(200).json(crops);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch crops' }); }
});

app.get('/api/admin/farms', async (req, res) => {
  try {
    const farms = await Farm.find().populate('userId', 'name email phone district').sort({ createdAt: -1 });
    res.status(200).json(farms);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch farms' }); }
});

app.get('/api/admin/activities', async (req, res) => {
  try {
    const tasks = await Task.find().populate('userId', 'name email').populate('cropId', 'cropType').sort({ scheduledDate: -1 });
    const today = new Date(); today.setHours(0, 0, 0, 0);
    const modifiedTasks = tasks.map(task => {
      let displayStatus = task.status;
      if (displayStatus === 'Pending' && task.scheduledDate) {
        const taskDate = new Date(task.scheduledDate); taskDate.setHours(0, 0, 0, 0);
        if (taskDate > today) displayStatus = 'Upcoming';
      }
      return { ...task.toObject(), status: displayStatus };
    });
    res.status(200).json(modifiedTasks);
  } catch (err) { res.status(500).json({ error: 'Failed to fetch activities' }); }
});

app.get('/api/weather', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.user.id || req.user._id);
    const locationQuery = req.query.location || user.district || 'Khulna';
    const response = await axios.get(`https://api.openweathermap.org/data/2.5/weather?q=${locationQuery},BD&units=metric&appid=${process.env.WEATHER_API_KEY}`);
    res.status(200).json({ location: response.data.name, temp: Math.round(response.data.main.temp), humidity: response.data.main.humidity, windSpeed: (response.data.wind.speed * 3.6).toFixed(1), condition: response.data.weather[0].main });
  } catch (err) { res.status(500).json({ error: 'Failed to fetch weather' }); }
});

app.put('/api/crops/:id', authenticate, async (req, res) => {
  try {
    const updatedCrop = await Crop.findByIdAndUpdate(req.params.id, { cropType: req.body.cropType, variety: req.body.variety, cultivationMethod: req.body.cultivationMethod }, { new: true });
    res.status(200).json({ message: 'Crop updated!', crop: updatedCrop });
  } catch (err) { res.status(500).json({ error: 'Failed to update crop' }); }
});

app.delete('/api/crops/:id', authenticate, async (req, res) => {
  try {
    await Crop.findByIdAndDelete(req.params.id); await Task.deleteMany({ cropId: req.params.id }); await CropIssue.deleteMany({ cropId: req.params.id });
    res.status(200).json({ message: 'Crop deleted' });
  } catch (error) { res.status(500).json({ error: 'Failed to delete crop' }); }
});

app.put('/api/farms/:id', authenticate, async (req, res) => {
  try {
    const updatedFarm = await Farm.findByIdAndUpdate(req.params.id, { name: req.body.name, landSize: req.body.landSize, location: req.body.location, soilType: req.body.soilType, ph: req.body.ph }, { new: true });
    res.status(200).json({ message: 'Farm updated!', farm: updatedFarm });
  } catch (err) { res.status(500).json({ error: 'Failed to update farm' }); }
});

app.delete('/api/farms/:id', authenticate, async (req, res) => {
  try {
    await Farm.findByIdAndDelete(req.params.id); await Crop.deleteMany({ farmId: req.params.id }); await Task.deleteMany({ farmId: req.params.id }); await CropIssue.deleteMany({ farmId: req.params.id });
    res.status(200).json({ message: 'Farm deleted' });
  } catch (error) { res.status(500).json({ error: 'Failed to delete farm' }); }
});

// ----------------------------------------------------
// 🌟 COMMUNITY FEED APIs
// ----------------------------------------------------

// ১. নতুন পোস্ট তৈরি করা
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

// 🌟 Crop Doctor এর সমস্যা এবং সমাধান কমিউনিটিতে শেয়ার করা
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
      solutionText = `🤖 AI সমাধান:\n${issue.aiAdvice}`;
    } else if (solutionType === 'Expert' && issue.expertReply) {
      solutionText = `👨‍🌾 বিশেষজ্ঞের সমাধান:\n${issue.expertReply}`;
    } else {
      return res.status(400).json({ error: 'No valid solution found to share.' });
    }

    const postText = `🚨 আমার ফসলের সমস্যা:\n${issue.issueText}\n\n✅ যে সমাধানটি আমার কাজে লেগেছে:\n${solutionText}`;

    // CommunityPost মডেলটি ইমপোর্ট করা থাকতে হবে (উপরে const CommunityPost = require('./src/CommunityPost');)
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

// ২. সব পোস্ট দেখা (স্মার্ট লোকেশন এবং সময় অনুযায়ী Priority)
app.get('/api/community/posts', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    
    // ১. ইউজারের লোকেশন বের করা
    const currentUser = await User.findById(userId);
    const userDistrict = currentUser?.district || '';

    // ২. ডাটাবেস থেকে সব পোস্ট নতুন থেকে পুরোনো (Newest First) অনুযায়ী আনা হলো
    let allPosts = await CommunityPost.find()
      .populate('userId', 'name profilePicture district')
      .populate('comments.userId', 'name profilePicture')
      .sort({ createdAt: -1 })
      .lean();

    // ৩. ফেসবুকের মতো স্মার্ট অ্যালগরিদম (Time + Location Priority)
    if (userDistrict) {
      const sevenDaysAgo = new Date();
      sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7); // ৭ দিনের সময়সীমা (Recent Time)

      // ক) নিজের জেলার 'সাম্প্রতিক' (গত ৭ দিনের) পোস্টগুলো (এগুলো সবার উপরে থাকবে)
      const recentLocalPosts = allPosts.filter(p => 
        p.location === userDistrict && new Date(p.createdAt) >= sevenDaysAgo
      );

      // খ) বাকি সব পোস্ট (নিজের জেলার ৭ দিনের পুরোনো পোস্ট + অন্য জেলার সব পোস্ট)
      // এগুলো অলরেডি Newest First অনুযায়ী সাজানো আছে
      const otherPosts = allPosts.filter(p => 
        !(p.location === userDistrict && new Date(p.createdAt) >= sevenDaysAgo)
      );
      
      // গ) জোড়া লাগানো (Recent Local গুলো উপরে, তারপর বাকি সব ক্রমানুসারে)
      allPosts = [...recentLocalPosts, ...otherPosts];
    }

    res.status(200).json(allPosts);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch posts.' });
  }
});

// ৩. পোস্টে লাইক দেওয়া / লাইক সরানো
app.put('/api/community/posts/:id/like', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const post = await CommunityPost.findById(req.params.id);

    if (!post) return res.status(404).json({ error: 'Post not found.' });

    const hasLiked = post.likes.includes(userId);
    if (hasLiked) {
      post.likes.pull(userId); // লাইক রিমুভ
    } else {
      post.likes.push(userId); // লাইক অ্যাড
    }

    await post.save();
    res.status(200).json({ message: hasLiked ? 'Unliked' : 'Liked', likesCount: post.likes.length });
  } catch (err) {
    res.status(500).json({ error: 'Failed to like/unlike post.' });
  }
});

// ৪. পোস্টে কমেন্ট করা
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

if (!MONGO_URI) { console.error('❌ Error: MONGO_URI is not defined in .env file!'); process.exit(1); }

mongoose.connect(MONGO_URI).then(() => {
  console.log('✅ MongoDB Connected Successfully!');
  app.listen(PORT, () => console.log(`🚀 Server running securely on http://localhost:${PORT}`));
}).catch(err => console.error('❌ Database connection error:', err.message));