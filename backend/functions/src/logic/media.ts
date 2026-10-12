// Maps a stored media URL back to its R2 object key.

/**
 * Returns the R2 object key for [url] when its host is one of [mediaHosts]
 * (the r2.dev public host and/or the custom CDN domain), else null. URLs on
 * any other host (e.g. legacy third-party art) are never touched.
 */
export function mediaKeyFromUrl(
  url: unknown,
  mediaHosts: string[],
): string | null {
  if (typeof url !== 'string' || url.length === 0) return null;
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return null;
  }
  const host = parsed.host.toLowerCase();
  if (!mediaHosts.map((h) => h.toLowerCase()).includes(host)) return null;
  const key = decodeURIComponent(parsed.pathname.replace(/^\/+/, ''));
  // Only ever delete objects under the folders the upload script writes to.
  if (!/^(audio|artwork)\/[^/]/.test(key) || key.includes('..')) return null;
  return key;
}

export function parseHostList(raw: string): string[] {
  return raw
    .split(',')
    .map((h) => h.trim())
    .filter(Boolean)
    .map((h) => h.replace(/^https?:\/\//, '').replace(/\/+$/, ''));
}
