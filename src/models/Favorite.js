import mongoose from 'mongoose';

const FavoriteSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true,
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
  embedUrl: {
    type: String,
  },
  source: {
    type: String,
    default: 'youtube',
  },
  favoritedAt: {
    type: Date,
    default: Date.now,
  },
});

// Đảm bảo không trùng lặp bài hát yêu thích của cùng một user
FavoriteSchema.index({ userId: 1, songId: 1 }, { unique: true });

export default mongoose.models.Favorite || mongoose.model('Favorite', FavoriteSchema);
