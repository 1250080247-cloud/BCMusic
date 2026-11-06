import Favorite from '@/models/Favorite';
import History from '@/models/History';
import Playlist from '@/models/Playlist';
import SoundCloudTrack from '@/models/SoundCloudTrack';

// Moves data created by a guest (`guest:<id>`) into a signed-in account.
// Rows keyed by (userId, songId) or (userId, scId) that exist in both places keep the account's copy,
// with the newer timestamp, and the guest copy is deleted.
export async function mergeGuestData(guestUserId, userId) {
  if (!guestUserId?.startsWith('guest:') || !userId || userId.startsWith('guest:')) {
    return { playlists: 0, history: 0, favorites: 0, soundcloud: 0 };
  }

  const playlists = await Playlist.updateMany({ userId: guestUserId }, { $set: { userId } });
  return {
    playlists: playlists.modifiedCount ?? 0,
    history: await mergeByKey(History, guestUserId, userId, 'songId', 'listenedAt'),
    favorites: await mergeByKey(Favorite, guestUserId, userId, 'songId', 'favoritedAt'),
    soundcloud: await mergeByKey(SoundCloudTrack, guestUserId, userId, 'scId', 'importedAt'),
  };
}

async function mergeByKey(Model, fromUser, toUser, keyField, timeField) {
  const guestRows = await Model.find({ userId: fromUser }).lean();
  let moved = 0;
  for (const row of guestRows) {
    const existing = await Model.findOne({ userId: toUser, [keyField]: row[keyField] }).lean();
    if (!existing) {
      await Model.updateOne({ _id: row._id }, { $set: { userId: toUser } });
      moved += 1;
      continue;
    }
    if (new Date(row[timeField]) > new Date(existing[timeField])) {
      await Model.updateOne({ _id: existing._id }, { $set: { [timeField]: row[timeField] } });
    }
    await Model.deleteOne({ _id: row._id });
  }
  return moved;
}
