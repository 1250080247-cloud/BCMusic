const AVATAR_HOSTS = ['googleusercontent.com', 'ggpht.com'];

export function isAllowedAvatar(image) {
  if (typeof image !== 'string') return false;
  if (!image) return true;
  if (/^data:image\/(png|jpeg|gif|webp);base64,[a-z\d+/]+={0,2}$/i.test(image)) {
    return Buffer.byteLength(image.slice(image.indexOf(',') + 1), 'base64') <= 2 * 1024 * 1024;
  }
  try {
    const url = new URL(image);
    const pathname = decodeURIComponent(url.pathname).replace(/\/+/g, '/').replace(/\/+$/, '');
    // External avatars are redirected to, so only hosts that serve Google profile pictures are accepted.
    const trustedHost = AVATAR_HOSTS.some((host) => url.hostname === host || url.hostname.endsWith(`.${host}`));
    return url.protocol === 'https:' && !url.username && !url.password && trustedHost && pathname !== '/api/user/avatar';
  } catch {
    return false;
  }
}
