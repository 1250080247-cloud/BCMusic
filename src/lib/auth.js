import CredentialsProvider from 'next-auth/providers/credentials';
import GoogleProvider from 'next-auth/providers/google';
import bcrypt from 'bcryptjs';
import dbConnect from '@/lib/mongodb';
import { consumeRateLimit } from '@/lib/rate-limit';
import User from '@/models/User';

// Unknown usernames still run one bcrypt comparison, so response time does not reveal which accounts exist.
let placeholderHash;
const dummyHash = () => (placeholderHash ??= bcrypt.hashSync('bcmusic-timing-placeholder', 10));

export const authOptions = {
  providers: [
    // ── Google OAuth ─────────────────────────────────
    GoogleProvider({
      clientId: process.env.GOOGLE_CLIENT_ID,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    }),

    // ── Username / Password ──────────────────────────
    CredentialsProvider({
      name: 'Credentials',
      credentials: {
        username: { label: 'Username', type: 'text' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (typeof credentials?.username !== 'string' || typeof credentials?.password !== 'string') return null;
        if (!credentials.username || !credentials.password) return null;

        const username = credentials.username.toLowerCase().trim();
        // Per-account limit: 10 attempts per 15 minutes. Authorize receives no client IP.
        if (!(await consumeRateLimit(`login:${username}`, { limit: 10, windowMs: 15 * 60_000 }))) return null;

        await dbConnect();
        const user = await User.findOne({ username });
        const isValid = await bcrypt.compare(credentials.password, user?.password || dummyHash());
        if (!user || !user.password || !isValid) return null; // no password = OAuth-only account

        return {
          id: user._id.toString(),
          name: user.displayName || user.username,
          username: user.username,
          image: user.image || null,
        };
      },
    }),
  ],

  callbacks: {
    // Called on every sign-in attempt
    async signIn({ account, profile }) {
      if (account?.provider === 'google') {
        try {
          await dbConnect();
          const existing = await User.findOne({ email: profile.email });
          if (!existing) {
            // Auto-create account from Google profile
            const base = (profile.email.split('@')[0])
              .replace(/[^a-z0-9]/gi, '')
              .toLowerCase()
              .slice(0, 20);
            const username = base + '_' + Date.now().toString(36).slice(-5);
            await User.create({
              username,
              displayName: profile.name,
              email: profile.email,
              image: profile.picture,
              password: null,
              provider: 'google',
            });
          }
          return true;
        } catch {
          return false;
        }
      }
      return true;
    },

    // Build JWT token
    async jwt({ token, user, account, trigger, session }) {
      // If the client triggers an update to the session
      if (trigger === 'update' && session?.user) {
        token.name = session.user.name;
        token.picture = `/api/user/avatar?userId=${token.userId}&t=${Date.now()}`;
        return token;
      }

      // Credentials login — user object is from authorize()
      if (user && account?.provider === 'credentials') {
        token.userId = user.id;
        token.username = user.username;
        token.name = user.name;
        token.picture = `/api/user/avatar?userId=${user.id}`;
        return token;
      }

      // Google login — look up our DB user by email (only on first sign-in when account is present)
      if (account?.provider === 'google') {
        await dbConnect();
        const dbUser = await User.findOne({ email: token.email }).lean();
        if (dbUser) {
          const userIdStr = dbUser._id.toString();
          token.userId = userIdStr;
          token.username = dbUser.username;
          token.name = dbUser.displayName || dbUser.username;
          token.picture = `/api/user/avatar?userId=${userIdStr}`;
        }
        return token;
      }

      return token;
    },

    // Expose data to client via useSession()
    async session({ session, token }) {
      session.user.id = token.userId;
      session.user.username = token.username;
      session.user.name = token.name;
      session.user.image = token.picture;
      return session;
    },
  },

  session: { strategy: 'jwt' },
  pages: { signIn: '/' },
  secret: process.env.NEXTAUTH_SECRET,
};

