// Pure home-feed assembly. The scheduled job fetches a few small, indexed
// queries and folds them into ONE Firestore document (`feeds/home`), so a Home
// screen open costs 1 read instead of ~150–200.

export interface DocRecord {
  id: string;
  data: Record<string, unknown>;
}

export interface HomeFeedInput {
  featured: DocRecord[];
  trending: DocRecord[];
  newReleases: DocRecord[];
  regions: Record<string, DocRecord[]>;
  albums: DocRecord[];
  artists: DocRecord[];
}

export interface HomeFeed {
  version: number;
  songs: Record<string, Record<string, unknown>>;
  featuredSongIds: string[];
  trendingSongIds: string[];
  newReleaseIds: string[];
  regionSongIds: Record<string, string[]>;
  albums: Record<string, unknown>[];
  artists: Record<string, unknown>[];
}

export const FEED_VERSION = 1;

/** Fields the app never reads from feed items — dropped to keep the doc small. */
const STRIPPED_FIELDS = [
  'titleLowercase',
  'nameLowercase',
  'searchKeywords',
  'createdAt',
  'updatedAt',
  'moderatedAt',
  'moderatedBy',
];

/** Firestore's hard limit is 1 MiB; stay well under it. */
export const FEED_SIZE_BUDGET_BYTES = 700 * 1024;

function strip(data: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data)) {
    if (!STRIPPED_FIELDS.includes(key)) out[key] = value;
  }
  return out;
}

function uniqueIds(records: DocRecord[]): string[] {
  return [...new Set(records.map((r) => r.id))];
}

/** Rough serialized size, used only for the budget check. */
export function approxSizeBytes(value: unknown): number {
  return Buffer.byteLength(JSON.stringify(value) ?? '', 'utf8');
}

export function buildHomeFeed(input: HomeFeedInput): HomeFeed {
  const songs: Record<string, Record<string, unknown>> = {};
  const addAll = (records: DocRecord[]) => {
    for (const r of records) songs[r.id] ??= strip(r.data);
  };
  addAll(input.featured);
  addAll(input.trending);
  addAll(input.newReleases);
  for (const records of Object.values(input.regions)) addAll(records);

  const regionSongIds: Record<string, string[]> = {};
  for (const [region, records] of Object.entries(input.regions)) {
    if (records.length > 0) regionSongIds[region] = uniqueIds(records);
  }

  const feed: HomeFeed = {
    version: FEED_VERSION,
    songs,
    featuredSongIds: uniqueIds(input.featured),
    trendingSongIds: uniqueIds(input.trending),
    newReleaseIds: uniqueIds(input.newReleases),
    regionSongIds,
    albums: input.albums.map((r) => ({ id: r.id, ...strip(r.data) })),
    artists: input.artists.map((r) => ({ id: r.id, ...strip(r.data) })),
  };

  // Lyrics are the only potentially large field. Drop them if the feed would
  // get close to the document limit. Songs opened from album/artist/search
  // pages still carry lyrics; only Home-row items lose them.
  if (approxSizeBytes(feed) > FEED_SIZE_BUDGET_BYTES) {
    for (const data of Object.values(feed.songs)) delete data.lyrics;
  }
  return feed;
}

/** Sort helpers mirroring the app's previous client-side ordering. */
export function byNumberDesc(field: string) {
  return (a: DocRecord, b: DocRecord) =>
    (Number(b.data[field]) || 0) - (Number(a.data[field]) || 0);
}
