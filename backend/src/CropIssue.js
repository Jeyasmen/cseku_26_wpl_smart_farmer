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
      type: String, // ফ্লাটার থেকে পাঠানো ছবির ডেটা (যদি থাকে)
      default: null,
    },
    aiAdvice: {
      type: String, // এআই কী উত্তর দিল সেটা এখানে সেভ থাকবে
    },
    needsExpert: {
      type: Boolean,
      default: false, // কৃষক "Ask Expert" এ ক্লিক করলে এটি true হবে
    },
    expertReply: {
      type: String, // অ্যাডমিন প্যানেল থেকে এক্সপার্ট উত্তর দিলে এখানে সেভ হবে
      default: null,
    },
    status: {
      type: String,
      enum: ['AI_Resolved', 'Pending_Expert', 'Expert_Resolved'],
      default: 'AI_Resolved',
    },
  },
  { timestamps: true } // কখন রিপোর্ট করা হয়েছে তার সময় ধরে রাখবে
);

module.exports = mongoose.model('CropIssue', cropIssueSchema);