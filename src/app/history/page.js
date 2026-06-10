import HistoryView from '@/components/HistoryView';
import dbConnect from '@/lib/mongodb';
import History from '@/models/History';
import { connection } from 'next/server';

async function getListeningHistory() {
  await connection();

  try {
    await dbConnect();
    const historyDocs = await History.find({}).sort({ listenedAt: -1 }).limit(30).lean();

    return historyDocs.map((doc) => ({
      id: doc.songId,
      title: doc.title,
      thumbnail: doc.thumbnail,
      artist: doc.artist,
      publishedAt: doc.publishedAt,
      lyrics: doc.lyrics,
      listenedAt: doc.listenedAt ? new Date(doc.listenedAt).toISOString() : null,
    }));
  } catch (error) {
    console.error("History fetch error:", error);
    return [];
  }
}

export default async function HistoryPage() {
  const songs = await getListeningHistory();

  return <HistoryView songs={songs} />;
}
