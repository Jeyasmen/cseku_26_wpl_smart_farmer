const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('./User');

const JWT_SECRET = process.env.JWT_SECRET || 'smart_farmer_super_secret_jwt_key_2026';

// Strict Email Format Checker (e.g. user@gmail.com)
const EMAIL_REGEX = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;

function formatUserResponse(userDoc) {
  const obj = userDoc.toObject ? userDoc.toObject() : { ...userDoc };
  delete obj.password;
  obj.id = obj._id;
  return obj;
}

// Register User (Farmer / Admin / Expert)
exports.signup = async (req, res) => {
  try {
    const {
      name,
      email,
      phone,
      password,
      role,
      village,
      district,
      designation,
      specialization,
      hotlineNumber,
      whatsappNumber,
      dutyHours,
    } = req.body;

    if (!name || !email || !password || !phone) {
      return res.status(400).json({ error: 'All fields are required' });
    }

    const cleanEmail = email.toLowerCase().trim();

    // Strict Email Validation
    if (!EMAIL_REGEX.test(cleanEmail)) {
      return res.status(400).json({ error: 'Invalid email format! Please enter a valid email (e.g. name@gmail.com).' });
    }

    // Phone Validation (Minimum 11 digits)
    const cleanPhoneDigits = phone.replace(/[^0-9]/g, '');
    if (cleanPhoneDigits.length < 11) {
      return res.status(400).json({ error: 'Please enter a valid 11-digit phone number.' });
    }

    // Password Length Check
    if (password.trim().length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters long.' });
    }

    const existingUser = await User.findOne({ email: cleanEmail });
    if (existingUser) {
      return res.status(400).json({ error: 'Email is already registered' });
    }

    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(password.trim(), salt);
    const assignedRole = role || 'farmer';

    const newUser = new User({
      name: name.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      password: hashedPassword,
      role: assignedRole,
      village: village || '',
      district: district || 'Khulna',
      badgeTitle: assignedRole === 'expert' ? 'Verified Expert 👨‍🌾' : (assignedRole === 'admin' ? 'Admin' : 'Active Farmer'),
      ...(assignedRole === 'expert' && {
        designation: designation || 'উপজেলা কৃষি কর্মকর্তা',
        specialization: specialization || 'ফসল রোগতত্ত্ব ও সার ব্যবস্থাপনা',
        hotlineNumber: hotlineNumber || phone.trim(),
        whatsappNumber: whatsappNumber || phone.trim(),
        dutyHours: dutyHours || 'সকাল ৯:০০ - বিকাল ৫:০০',
        isAvailable: true,
      }),
    });

    await newUser.save();

    const token = jwt.sign(
      { id: newUser._id, userId: newUser._id, email: newUser.email, role: newUser.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({
      message: 'User registered successfully in MongoDB',
      token,
      user: formatUserResponse(newUser),
    });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'Server error during signup' });
  }
};

// Login User (Farmer, Expert & Admin)
exports.signin = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required' });
    }

    const cleanEmail = email.toLowerCase().trim();
    const cleanPassword = password.trim();

    if (!EMAIL_REGEX.test(cleanEmail)) {
      return res.status(400).json({ error: 'Please enter a valid email address (e.g. user@gmail.com).' });
    }

    const user = await User.findOne({ email: cleanEmail });
    if (!user) {
      return res.status(400).json({ error: 'Invalid email or password.' });
    }

    let isMatch = false;
    if (user.password && (user.password.startsWith('$2a$') || user.password.startsWith('$2b$'))) {
      isMatch = await bcrypt.compare(cleanPassword, user.password);
    } else {
      isMatch = (cleanPassword === user.password);
    }

    if (!isMatch) {
      return res.status(400).json({ error: 'Invalid email or password.' });
    }

    const token = jwt.sign(
      { id: user._id, userId: user._id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(200).json({
      message: 'Login successful',
      token,
      user: formatUserResponse(user),
    });
  } catch (error) {
    console.error('Signin error:', error);
    res.status(500).json({ error: 'Server error during signin' });
  }
};