import mongoose from 'mongoose';

// Fixed-window counters. MongoDB removes each document once its window ends.
const RateLimitSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  count: { type: Number, default: 0 },
  resetAt: { type: Date, required: true, index: { expires: 0 } },
}, { versionKey: false });

export default mongoose.models.RateLimit || mongoose.model('RateLimit', RateLimitSchema);
