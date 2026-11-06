import dbConnect from '@/lib/mongodb';
import RateLimit from '@/models/RateLimit';

// Client identity for anonymous limits. Vercel sets x-forwarded-for from the real socket.
export function clientKey(request) {
  const forwarded = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim();
  return forwarded || request.headers.get('x-real-ip') || 'unknown';
}

// Returns false when `name` has used more than `limit` calls in the current window.
// The counter lives in MongoDB so every serverless instance shares it. It fails open:
// if the database is unreachable, users are not blocked, and the error is logged.
export async function consumeRateLimit(name, { limit, windowMs }) {
  try {
    await dbConnect();
    const now = Date.now();
    const current = await RateLimit.findOneAndUpdate(
      { _id: name, resetAt: { $gt: new Date(now) } },
      { $inc: { count: 1 } },
      { returnDocument: 'after' }
    ).lean();
    if (current) return current.count <= limit;

    await RateLimit.findOneAndUpdate(
      { _id: name },
      { $set: { count: 1, resetAt: new Date(now + windowMs) } },
      { upsert: true }
    );
    return true;
  } catch (error) {
    console.error('Rate limit unavailable:', error.name);
    return true;
  }
}
