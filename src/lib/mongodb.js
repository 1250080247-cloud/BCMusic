import mongoose from 'mongoose';
import dns from 'node:dns';

const MONGODB_URI = process.env.MONGODB_URI;

if (!MONGODB_URI) {
  throw new Error('Vui lòng định nghĩa biến MONGODB_URI trong file .env.local');
}

// Optional process-local workaround for Node's SRV resolver on some Windows hosts.
// Leave unset on deployments whose system DNS already works.
const dnsServers = process.env.MONGODB_DNS_SERVERS?.split(',').map((server) => server.trim()).filter(Boolean);
if (MONGODB_URI.startsWith('mongodb+srv://') && dnsServers?.length) {
  dns.setServers(dnsServers);
  // Next.js may load node:dns/promises before the dns.promises getter is used.
  // In that order, Node's callback setter leaves the promise resolver unchanged.
  dns.promises.setServers(dnsServers);
}

let cached = global.mongoose;

if (!cached) {
  cached = global.mongoose = { conn: null, promise: null };
}

async function dbConnect() {
  if (cached.conn) {
    return cached.conn;
  }

  if (!cached.promise) {
    const opts = {
      bufferCommands: false,
    };

    cached.promise = mongoose.connect(MONGODB_URI, opts).then((mongoose) => {
      return mongoose;
    });
  }
  try {
    cached.conn = await cached.promise;
  } catch (error) {
    cached.promise = null;
    throw error;
  }
  return cached.conn;
}

export default dbConnect;
