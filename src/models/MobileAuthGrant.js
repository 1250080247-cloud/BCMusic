import mongoose from 'mongoose';

const MobileAuthGrantSchema = new mongoose.Schema({
  _id: { type: String, required: true },
  userId: { type: mongoose.Schema.Types.ObjectId, required: true },
  state: { type: String, required: true },
  challenge: { type: String, required: true },
  expiresAt: { type: Date, required: true, index: { expires: 0 } },
}, { versionKey: false });

export default mongoose.models.MobileAuthGrant || mongoose.model('MobileAuthGrant', MobileAuthGrantSchema);
