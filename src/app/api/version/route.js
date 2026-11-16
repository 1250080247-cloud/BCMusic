import { safeHttpsUrl } from '@/lib/url-policy';

export function GET() {
  const version = process.env.BCMUSIC_ANDROID_VERSION?.trim();
  const downloadUrl = safeHttpsUrl(process.env.BCMUSIC_ANDROID_DOWNLOAD_URL?.trim());
  if (!version || !/^\d{1,9}\.\d{1,9}\.\d{1,9}$/.test(version) || !downloadUrl) {
    return new Response(null, { status: 204 });
  }

  return Response.json({
    version,
    downloadUrl,
    date: process.env.BCMUSIC_ANDROID_RELEASE_DATE?.trim().slice(0, 32) ?? '',
    changelog: process.env.BCMUSIC_ANDROID_CHANGELOG?.trim().slice(0, 4000) ?? '',
  });
}
