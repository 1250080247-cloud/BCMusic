import mongoose from 'mongoose';

const YouTubeSongSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    title: { type: String, required: true },
    artist: { type: String, default: '' },
    thumbnail: { type: String, default: '' },
    durationSeconds: { type: Number, default: null },
  },
  { _id: false },
);

const YouTubePlaylistSchema = new mongoose.Schema(
  {
    id: { type: String, required: true },
    name: { type: String, required: true },
    itemCount: { type: Number, default: 0 },
    thumbnail: { type: String, default: '' },
    songs: { type: [YouTubeSongSchema], default: [] },
  },
  { _id: false },
);

const YouTubeConnectionSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true, index: true },
    encryptedRefreshToken: { type: String, default: null },
    encryptedAccessToken: { type: String, default: null },
    accessTokenExpiresAt: { type: Date, default: null },
    status: {
      type: String,
      enum: ['connected', 'expired'],
      default: 'connected',
    },
    lastSyncedAt: { type: Date, default: null },
    likedSongs: { type: [YouTubeSongSchema], default: [] },
    playlists: { type: [YouTubePlaylistSchema], default: [] },
    subscribedArtists: { type: [String], default: [] },
    topArtists: { type: [String], default: [] },
  },
  { timestamps: true, versionKey: false },
);

export default mongoose.models.YouTubeConnection ||
  mongoose.model('YouTubeConnection', YouTubeConnectionSchema);
