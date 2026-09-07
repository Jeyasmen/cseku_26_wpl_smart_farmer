const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    farmId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Farm',
    },
    cropId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Crop',
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    activityType: {
      type: String,
      enum: ['Watering', 'Fertilizing', 'Pesticide', 'Weeding', 'Harvesting', 'Other'],
      default: 'Other',
    },
    scheduledDate: {
      type: Date,
      required: true,
    },
    isUrgent: {
      type: Boolean,
      default: false,
    },
    status: {
      type: String,
      enum: ['Pending', 'Completed', 'Overdue'],
      default: 'Pending',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Task', taskSchema);