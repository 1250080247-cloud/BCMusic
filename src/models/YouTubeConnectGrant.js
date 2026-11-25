import mongoose from 'mongoose';

const YouTubeConnectGrantSchema = new mongoose.Schema(
  {
    _id: { type: String, required: true },
    userId: { type: String, required: true },
    expiresAt: { type: Date, required: true, index: { expires: 0 } },
  },
  { versionKey: false },
);

export default mongoose.models.YouTubeConnectGrant ||
  mongoose.model('YouTubeConnectGrant', YouTubeConnectGrantSchema);
