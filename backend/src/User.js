const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  bio: { type: String, default: '' },
  profilePicture: { type: String, default: '' },
  phone: {
    type: String,
    required: true,
    trim: true,
  },
  password: {
    type: String,
    required: true,
  },
  role: {
    type: String,
    enum: ['farmer', 'buyer', 'expert', 'admin'],
    default: 'farmer',
  },
  village: {
    type: String,
    trim: true,
    default: '',
  },
  district: {
    type: String,
    trim: true,
    default: '',
  },
  isTopFarmer: {
    type: Boolean,
    default: false,
  },
  badgeTitle: {
    type: String,
    default: 'Active Farmer',
  },
  // 👨‍🌾 নিয়োগপ্রাপ্ত কৃষি বিশেষজ্ঞের (Expert Job Profile) অতিরিক্ত তথ্য
  designation: {
    type: String,
    default: 'উপজেলা কৃষি কর্মকর্তা',
    trim: true,
  },
  specialization: {
    type: String,
    default: 'ফসল রোগতত্ত্ব ও সার ব্যবস্থাপনা',
    trim: true,
  },
  hotlineNumber: {
    type: String,
    default: '',
    trim: true,
  },
  whatsappNumber: {
    type: String,
    default: '',
    trim: true,
  },
  dutyHours: {
    type: String,
    default: 'সকাল ৯:০০ - বিকাল ৫:০০',
    trim: true,
  },
  isAvailable: {
    type: Boolean,
    default: true,
  },
  resolvedIssuesCount: {
    type: Number,
    default: 0,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

module.exports = mongoose.model('User', userSchema);