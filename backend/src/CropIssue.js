const mongoose = require('mongoose');

const cropIssueSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    cropId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Crop',
      required: true,
    },
    issueText: {
      type: String,
      required: true,
    },
    imageBase64: {
      type: String,
      default: null,
    },
    aiAdvice: {
      type: String,
      default: '',
    },
    needsExpert: {
      type: Boolean,
      default: false,
    },
    // 👨‍🌾 কৃষক যে নির্দিষ্ট বিশেষজ্ঞকে বাছাই করে সমস্যা পাঠিয়েছেন
    assignedExpert: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    expertReply: {
      type: String,
      default: '',
    },
    // 👨‍🌾 কোন কৃষি কর্মকর্তা সমাধান দিয়েছেন
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    resolvedAt: {
      type: Date,
      default: null,
    },
    status: {
      type: String,
      enum: ['AI_Resolved', 'Pending_Expert', 'Expert_Resolved'],
      default: 'AI_Resolved',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('CropIssue', cropIssueSchema);