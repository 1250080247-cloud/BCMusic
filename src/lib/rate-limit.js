import { isIP } from 'node:net';
import dbConnect from '@/lib/mongodb';
import RateLimit from '@/models/RateLimit';

// Trust platform-supplied addresses only on Vercel deployments.
export function clientKey(request) {
  if (process.env.VERCEL === '1') {
    for (const header of ['x-vercel-forwarded-for', 'x-real-ip']) {
      const address = request.headers.get(header)?.trim();
      if (address && isIP(address)) return address;
    }
  }
  return 'unknown';
}

// Returns false when `name` has used more than `limit` calls in the current window.
// The counter lives in MongoDB so every serverless instance shares it. It fails open:
// if the database is unreachable, users are not blocked, and the error is logged.
export async function consumeRateLimit(name, { limit, windowMs }) {
  try {
    await dbConnect();
    const active = { $gt: ['$resetAt', '$$NOW'] };
    const update = [{ $set: {
      count: { $cond: [active, { $add: ['$count', 1] }, 1] },
      resetAt: { $cond: [active, '$resetAt', { $add: ['$$NOW', windowMs] }] },
    } }];
    const increment = () => RateLimit.findOneAndUpdate(
      { _id: name },
      update,
      { upsert: true, returnDocument: 'after', updatePipeline: true },
    ).lean();
    const current = await increment().catch((error) => {
      if (error.code !== 11000) throw error;
      return increment();
    });
    return current.count <= limit;
  } catch (error) {
    console.error('Rate limit unavailable:', error.name);
    return true;
  }
}
