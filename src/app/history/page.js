import { getRequestUserId } from '@/lib/request-user';
import { restoreSoundCloudMetadata } from '@/lib/song-metadata';
import HistoryView from '@/components/HistoryView';
import dbConnect from '@/lib/mongodb';
import History from '@/models/History';
import { connection } from 'next/server';

async function getListeningHistory(userId) {
  await connection();
  if (!userId) return [];

  try {
    await dbConnect();

    const query = { userId };
    const historyDocs = await History.find(query).sort({ listenedAt: -1 }).limit(50).lean();

    const songs = historyDocs.map((doc) => ({
      id: doc.songId,
      title: doc.title,
      thumbnail: doc.thumbnail,
      artist: doc.artist,
      publishedAt: doc.publishedAt,
      lyrics: doc.lyrics,
      embedUrl: doc.embedUrl,
      sourceUrl: doc.sourceUrl,
      source: doc.source || 'youtube',
      listenedAt: doc.listenedAt ? new Date(doc.listenedAt).toISOString() : null,
    }));
    return await restoreSoundCloudMetadata(songs, userId);
  } catch (error) {
    console.error('History fetch error:', error);
    return [];
  }
}

export default async function HistoryPage() {
  const userId = await getRequestUserId({ allowGuest: true });
  const songs = await getListeningHistory(userId);

  return <HistoryView songs={songs} />;
}
