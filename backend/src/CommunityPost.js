const mongoose = require('mongoose');

const CommunityPostSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  cropIssueId: { type: mongoose.Schema.Types.ObjectId, ref: 'CropIssue' }, // যদি AI/Expert issue থেকে আসে
  text: { type: String, required: true },
  imageBase64: { type: String }, // ছবি থাকলে
  location: { type: String }, // ইউজারের জেলা বা লোকেশন (লোকাল ফিডের জন্য)
  likes: [{ type: mongoose.Schema.Types.ObjectId, ref: 'User' }], // যারা লাইক করেছে
  comments: [
    {
      userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
      text: { type: String, required: true },
      createdAt: { type: Date, default: Date.now }
    }
  ],
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model('CommunityPost', CommunityPostSchema);