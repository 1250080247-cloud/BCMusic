import mongoose from 'mongoose';

const SoundCloudTrackSchema = new mongoose.Schema({
  // Unique SoundCloud ID (e.g. "sc_123456")
  scId: {
    type: String,
    required: true,
    index: true,
  },
  // Numeric SoundCloud track ID (extracted from oEmbed)
  scTrackId: {
    type: String,
    default: null,
  },
  title: {
    type: String,
    required: true,
  },
  artist: {
    type: String,
    default: 'Unknown Artist',
  },
  thumbnail: {
    type: String,
    default: null,
  },
  // Original SoundCloud URL provided by the user
  sourceUrl: {
    type: String,
    required: true,
  },
  // SoundCloud Widget embed URL for playback
  embedUrl: {
    type: String,
    required: true,
  },
  // Anonymous user who imported this track
  userId: {
    type: String,
    required: true,
    index: true,
  },
  importedAt: {
    type: Date,
    default: Date.now,
  },
});

// Compound index: one user cannot import the same track twice
SoundCloudTrackSchema.index({ userId: 1, scId: 1 }, { unique: true });

export default mongoose.models.SoundCloudTrack || mongoose.model('SoundCloudTrack', SoundCloudTrackSchema);
