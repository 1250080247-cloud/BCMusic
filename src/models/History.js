import mongoose from 'mongoose';

const HistorySchema = new mongoose.Schema({
  userId: {
    type: String,
    index: true,
    default: null,
  },
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
  source: {
    type: String,
    default: 'youtube',
  },
  listenedAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
});

// Compound unique index: mỗi user chỉ có 1 document cho mỗi bài hát
// → đảm bảo upsert không tạo trùng, chỉ cập nhật listenedAt
HistorySchema.index({ userId: 1, songId: 1 }, { unique: true });

export default mongoose.models.History || mongoose.model('History', HistorySchema);

