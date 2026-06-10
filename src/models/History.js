import mongoose from 'mongoose';

const HistorySchema = new mongoose.Schema({
  songId: {
    type: String,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  thumbnail: {
    type: String,
  },
  artist: {
    type: String,
  },
  publishedAt: {
    type: String,
  },
  lyrics: {
    type: String,
  },
  listenedAt: {
    type: Date,
    default: Date.now,
  },
});

export default mongoose.models.History || mongoose.model('History', HistorySchema);
