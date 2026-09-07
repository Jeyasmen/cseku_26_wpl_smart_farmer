const mongoose = require('mongoose');

const farmSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
    landSize: {
      type: Number,
      required: true,
    },
    unit: {
      type: String,
      default: 'Acres',
    },
    location: {
      type: String,
      default: '',
      trim: true,
    },
    soilType: {
      type: String,
      default: 'Loamy',
    },
    ph: {
      type: Number,
      default: null,
    },
    description: {
      type: String,
      default: '',
      trim: true,
    },
    status: {
      type: String,
      enum: ['active', 'inactive'],
      default: 'active',
    },
  },
  { timestamps: true }
);

module.exports = mongoose.model('Farm', farmSchema);