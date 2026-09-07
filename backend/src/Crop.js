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
    cultivationMethod: {
      type: String,
      default: 'Open Field',
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
    // নতুন যুক্ত করা ফিল্ডগুলো
    totalExpense: {
      type: Number,
      default: 0,
    },
    expenses: [
      {
        title: String,
        amount: Number,
        date: { type: Date, default: Date.now },
      }
    ],
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