const mongoose = require('mongoose');

const cropSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    farmId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Farm',
      required: true,
    },
    cropCategory: {
      type: String,
      default: 'শাকসবজি (Vegetables)',
      trim: true,
    },
    cropType: {
      type: String,
      required: true,
      trim: true,
    },
    variety: {
      type: String,
      default: '',
      trim: true,
    },
    // আবাদকৃত জমির পরিমাণ ও একক
    allocatedArea: {
      type: Number,
      default: 0,
    },
    areaUnit: {
      type: String,
      default: 'শতাংশ (Decimal)',
    },
    // বীজ বা চারার পরিমাণ, একক ও উৎস
    seedQuantity: {
      type: Number,
      default: 0,
    },
    seedUnit: {
      type: String,
      default: 'গ্রাম (gm)',
    },
    seedSource: {
      type: String,
      default: 'স্থানীয় অনুমোদিত ডিলার',
    },
    // উপযুক্ত নতুন ফসল হলে অন্য কৃষকদের লিস্টে দেখানোর ফ্ল্যাগ
    isCatalogApproved: {
      type: Boolean,
      default: false,
    },
    cultivationMethod: {
      type: String,
      default: 'Open Field (মাঠ)',
    },
    description: {
      type: String,
      default: '',
    },
    sowingDate: {
      type: Date,
      required: true,
    },
    currentStage: {
      type: String,
      enum: ['Germination', 'Vegetative', 'Flowering', 'Ripening', 'Harvested'],
      default: 'Germination',
    },
    expectedHarvestDate: {
      type: Date,
    },
    status: {
      type: String,
      enum: ['In Progress', 'Harvested', 'Failed'],
      default: 'In Progress',
    },
    totalExpense: {
      type: Number,
      default: 0,
    },
    expenses: [
      {
        title: String,
        category: {
          type: String,
          default: 'Other',
        },
        amount: Number,
        date: { type: Date, default: Date.now },
      }
    ],
    aiExpenseAnalysis: {
      type: String,
      default: '',
    },
    diaryNotes: [
      {
        note: String,
        date: { type: Date, default: Date.now },
      }
    ]
  },
  { timestamps: true }
);

module.exports = mongoose.model('Crop', cropSchema);