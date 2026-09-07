const express = require('express');
const cors = require('cors');
const mongoose = require('mongoose');
require('dotenv').config();

const { signup, signin } = require('./src/auth');
const { authenticate } = require('./src/authMiddleware');
const User = require('./src/User');
const Farm = require('./src/Farm');
const Crop = require('./src/Crop');
const Task = require('./src/Task');

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
app.use(express.json());

// Request logger
app.use((req, res, next) => {
  console.log(`📡 [${req.method}] ${req.url}`);
  next();
});

// 2. Health check endpoint
app.get('/api/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Server is healthy and running' });
});

// 3. Authentication endpoints
app.post('/api/auth/signup', signup);
app.post('/api/auth/signin', signin);

// 4. Protected Profile endpoint
app.get('/api/auth/me', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.user.id || req.user._id).select('-password');
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.status(200).json(user);
  } catch (err) {
    res.status(500).json({ error: 'Server error fetching profile' });
  }
});

// ----------------------------------------------------
// 5. FARM APIs (খামার তৈরি ও তালিকা)
// ----------------------------------------------------

app.post('/api/farms', authenticate, async (req, res) => {
  try {
    const { name, landSize, location, soilType, ph, description } = req.body;
    const userId = req.user.id || req.user._id;

    if (!name || !landSize) {
      return res.status(400).json({ error: 'Farm name and land size are required.' });
    }

    const newFarm = new Farm({
      userId,
      name,
      landSize: Number(landSize),
      location: location || '',
      soilType: soilType || 'Loamy',
      ph: ph ? Number(ph) : null,
      description: description || '',
    });

    await newFarm.save();
    console.log('✅ New Farm Created:', newFarm.name);
    res.status(201).json({ message: 'Farm created successfully', farm: newFarm });
  } catch (err) {
    console.error('Error creating farm:', err);
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

    res.status(200).json({
      activeFarmsCount,
      activeCropsCount: activeCrops.length,
      urgentTasksCount: urgentTasks.length,
      urgentTasks,
      activeCrops,
    });
  } catch (err) {
    console.error('Error fetching dashboard summary:', err);
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
        
        return {
          ...farm.toObject(),
          totalExpense,
          cropsCount: crops.length,
        };
      })
    );

    res.status(200).json(farmsWithExpenses);
  } catch (err) {
    console.error('Error fetching farms with expenses:', err);
    res.status(500).json({ error: 'Failed to fetch farms' });
  }
});

// ----------------------------------------------------
// 6. CROP APIs (ফসল যোগ করা ও স্বয়ংক্রিয় টাস্ক তৈরি)
// ----------------------------------------------------

app.post('/api/crops', authenticate, async (req, res) => {
  try {
    const { farmId, cropType, variety, sowingDate, cultivationMethod, description } = req.body;
    const userId = req.user.id || req.user._id;

    if (!farmId || !cropType || !sowingDate) {
      return res.status(400).json({ error: 'Farm, crop type, and sowing date are required.' });
    }

    const startDate = new Date(sowingDate);
    const harvestDate = new Date(startDate);
    harvestDate.setDate(harvestDate.getDate() + 90);

    const newCrop = new Crop({
      userId,
      farmId,
      cropType,
      variety: variety || '',
      cultivationMethod: cultivationMethod || 'Open Field',
      description: description || '',
      sowingDate: startDate,
      expectedHarvestDate: harvestDate,
      currentStage: 'Germination',
    });

    await newCrop.save();

    const initialTasks = [
      {
        userId,
        farmId,
        cropId: newCrop._id,
        title: `${cropType}: প্রাথমিক সেচ দিন (First Irrigation)`,
        activityType: 'Watering',
        scheduledDate: new Date(startDate.getTime() + 2 * 24 * 60 * 60 * 1000),
        isUrgent: true,
      },
      {
        userId,
        farmId,
        cropId: newCrop._id,
        title: `${cropType}: ১ম কিস্তি সার প্রয়োগ (Fertilizer Application)`,
        activityType: 'Fertilizing',
        scheduledDate: new Date(startDate.getTime() + 15 * 24 * 60 * 60 * 1000),
        isUrgent: false,
      },
      {
        userId,
        farmId,
        cropId: newCrop._id,
        title: `${cropType}: আগাছা পরিষ্কার ও পোকা পর্যবেক্ষণ (Weeding & Pest Check)`,
        activityType: 'Weeding',
        scheduledDate: new Date(startDate.getTime() + 25 * 24 * 60 * 60 * 1000),
        isUrgent: false,
      }
    ];

    await Task.insertMany(initialTasks);

    res.status(201).json({ 
      message: 'Crop added and automatic task schedule created!', 
      crop: newCrop 
    });
  } catch (err) {
    console.error('Error adding crop:', err);
    res.status(500).json({ error: 'Failed to add crop' });
  }
});

app.get('/api/crops/my', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const crops = await Crop.find({ userId }).populate('farmId', 'name location').sort({ createdAt: -1 });
    res.status(200).json(crops);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch crops' });
  }
});

app.get('/api/crops/:id/details', authenticate, async (req, res) => {
  try {
    const cropId = req.params.id;
    const crop = await Crop.findById(cropId).populate('farmId', 'name');
    if (!crop) return res.status(404).json({ error: 'Crop not found' });
    
    const tasks = await Task.find({ cropId }).sort({ scheduledDate: 1 });
    
    res.status(200).json({ crop, tasks });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch crop details' });
  }
});

app.post('/api/crops/:id/expenses', authenticate, async (req, res) => {
  try {
    const { title, amount } = req.body;
    const crop = await Crop.findById(req.params.id);
    if (!crop) return res.status(404).json({ error: 'Crop not found' });

    const expenseAmount = Number(amount);
    crop.expenses.unshift({ title, amount: expenseAmount }); 
    crop.totalExpense += expenseAmount;
    await crop.save();

    res.status(200).json(crop);
  } catch (err) {
    res.status(500).json({ error: 'Failed to add expense' });
  }
});

app.post('/api/crops/:id/notes', authenticate, async (req, res) => {
  try {
    const { note } = req.body;
    const crop = await Crop.findById(req.params.id);
    if (!crop) return res.status(404).json({ error: 'Crop not found' });

    crop.diaryNotes.unshift({ note }); 
    await crop.save();

    res.status(200).json(crop);
  } catch (err) {
    res.status(500).json({ error: 'Failed to add note' });
  }
});

// ----------------------------------------------------
// 7. TASK APIs (কাজের তালিকা ও স্ট্যাটাস আপডেট)
// ----------------------------------------------------

app.get('/api/tasks/my', authenticate, async (req, res) => {
  try {
    const userId = req.user.id || req.user._id;
    const tasks = await Task.find({ userId })
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
    const { id } = req.params;
    const task = await Task.findByIdAndUpdate(
      id,
      { status: 'Completed' },
      { new: true }
    );
    res.status(200).json({ message: 'Task marked as completed', task });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update task' });
  }
});

// ----------------------------------------------------
// 8. ADMIN PANEL APIs (এডমিনদের জন্য ডাটা)
// ----------------------------------------------------

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
    res.status(200).json({ message: 'User deleted successfully' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

app.put('/api/admin/users/:id/role', async (req, res) => {
  try {
    const { role } = req.body;
    const updatedUser = await User.findByIdAndUpdate(req.params.id, { role }, { new: true }).select('-password');
    res.status(200).json({ message: 'Role updated', user: updatedUser });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update role' });
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
    res.status(500).json({ error: 'Failed to fetch crops for admin' });
  }
});

app.get('/api/admin/farms', async (req, res) => {
  try {
    const farms = await Farm.find()
      .populate('userId', 'name email phone district')
      .sort({ createdAt: -1 });
    res.status(200).json(farms);
  } catch (err) {
    console.error('Error fetching farms for admin:', err);
    res.status(500).json({ error: 'Failed to fetch farms for admin' });
  }
});

// 🚀 FIXED: Activities API with Dynamic "Upcoming" Status 🚀
app.get('/api/admin/activities', async (req, res) => {
  try {
    const tasks = await Task.find()
      .populate('userId', 'name email')
      .populate('cropId', 'cropType')
      .sort({ scheduledDate: -1 });

    // বর্তমান সময় বের করা (শুধু তারিখ মেলানোর জন্য সময় 00:00 করে নেওয়া হচ্ছে)
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // লজিক চেক করে স্ট্যাটাস পরিবর্তন করা
    const modifiedTasks = tasks.map(task => {
      let displayStatus = task.status; // ডিফল্ট স্ট্যাটাস (Pending বা Completed)

      if (displayStatus === 'Pending' && task.scheduledDate) {
        const taskDate = new Date(task.scheduledDate);
        taskDate.setHours(0, 0, 0, 0);

        if (taskDate > today) {
          displayStatus = 'Upcoming'; // ভবিষ্যতের কাজ হলে Upcoming দেখাবে
        }
      }

      // Mongoose অবজেক্টকে রেগুলার অবজেক্টে রূপান্তর করে স্ট্যাটাস আপডেট করে পাঠানো
      return { 
        ...task.toObject(), 
        status: displayStatus 
      };
    });

    res.status(200).json(modifiedTasks);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch activities for admin' });
  }
});

// ----------------------------------------------------
// 9. Database Connection & Server Start
// ----------------------------------------------------
if (!MONGO_URI) {
  console.error('❌ Error: MONGO_URI is not defined in .env file!');
  process.exit(1);
}

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log('✅ MongoDB Connected Successfully!');
    app.listen(PORT, () => {
      console.log(`🚀 Server running securely on http://localhost:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('❌ Database connection error:', err.message);
  });