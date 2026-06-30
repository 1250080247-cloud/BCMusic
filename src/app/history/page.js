import { getServerSession } from 'next-auth';
import { authOptions } from '@/app/api/auth/[...nextauth]/route';
import HistoryView from '@/components/HistoryView';
import dbConnect from '@/lib/mongodb';
import History from '@/models/History';
import { connection } from 'next/server';

async function getListeningHistory(userId) {
  await connection();

  try {
    await dbConnect();

    // If user is logged in, show only their history; else show anonymous
    const query = userId ? { userId } : { userId: null };
    const historyDocs = await History.find(query).sort({ listenedAt: -1 }).limit(50).lean();

    return historyDocs.map((doc) => ({
      id: doc.songId,
      title: doc.title,
      thumbnail: doc.thumbnail,
      artist: doc.artist,
      publishedAt: doc.publishedAt,
      lyrics: doc.lyrics,
      source: doc.source || 'youtube',
      listenedAt: doc.listenedAt ? new Date(doc.listenedAt).toISOString() : null,
    }));
  } catch (error) {
    console.error('History fetch error:', error);
    return [];
  }
}

export default async function HistoryPage() {
  const session = await getServerSession(authOptions);
  const userId = session?.user?.id || null;
  const songs = await getListeningHistory(userId);

  return <HistoryView songs={songs} />;
}
