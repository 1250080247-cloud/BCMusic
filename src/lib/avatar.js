export function isAllowedAvatar(image) {
  if (typeof image !== 'string') return false;
  if (!image) return true;
  if (/^data:image\/(png|jpeg|gif|webp);base64,[a-z\d+/]+={0,2}$/i.test(image)) {
    return Buffer.byteLength(image.slice(image.indexOf(',') + 1), 'base64') <= 2 * 1024 * 1024;
  }
  try {
    const url = new URL(image);
    const pathname = decodeURIComponent(url.pathname).replace(/\/+/g, '/').replace(/\/+$/, '');
    return url.protocol === 'https:' && !url.username && !url.password && pathname !== '/api/user/avatar';
  } catch {
    return false;
  }
}
