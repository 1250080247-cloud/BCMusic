import mongoose from 'mongoose';

const SongSubSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    title: { type: String, required: true },
    thumbnail: { type: String },
    artist: { type: String },
    publishedAt: { type: String },
    source: { type: String, default: 'youtube' },
    embedUrl: { type: String },
    sourceUrl: { type: String },
  },
  { _id: false }
);

const PlaylistSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    index: true,
  },
  name: {
    type: String,
    required: true,
  },
  songs: {
    type: [SongSubSchema],
    default: [],
  },
  // Public playlists are readable at /shared/[id] without signing in.
  isPublic: {
    type: Boolean,
    default: false,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
});

export default mongoose.models.Playlist || mongoose.model('Playlist', PlaylistSchema);
