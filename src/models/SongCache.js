import mongoose from 'mongoose';

const CachedSongSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    title: { type: String, required: true },
    artist: { type: String },
    thumbnail: { type: String },
    publishedAt: { type: String },
    viewCount: { type: String },
  },
  { _id: false }
);

const SongCacheSchema = new mongoose.Schema({
  // Unique key for this cache entry, e.g. "tiktok remix ncs__viewCount__5"
  cacheKey: {
    type: String,
    required: true,
    unique: true,
    index: true,
  },
  query: {
    type: String,
    required: true,
  },
  order: {
    type: String,
    required: true,
    enum: ['relevance', 'viewCount', 'date'],
  },
  maxResults: {
    type: Number,
    default: 5,
  },
  songs: {
    type: [CachedSongSchema],
    default: [],
  },
  nextPageToken: {
    type: String,
    default: null,
  },
  prevPageToken: {
    type: String,
    default: null,
  },
  // Cache expiry: entries older than this are considered stale
  cachedAt: {
    type: Date,
    default: Date.now,
    index: true,
  },
});

// TTL index: MongoDB will automatically delete documents 1 hour after cachedAt
SongCacheSchema.index({ cachedAt: 1 }, { expireAfterSeconds: 3600 });

export default mongoose.models.SongCache || mongoose.model('SongCache', SongCacheSchema);
