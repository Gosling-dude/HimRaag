// Pure play-count logic: payload validation, daily quota, trending score.
// Kept free of Firebase imports so it can be unit-tested with `node --test`.

export type PlayCounts = Record<string, number>;

/** Max distinct songs accepted in one recordPlays call. */
export const MAX_SONGS_PER_CALL = 50;

/** Max plays of a single song accepted in one call (a client flushes every
 *  ~10 plays, so anything near this is already suspicious). */
export const MAX_PLAYS_PER_SONG_PER_CALL = 20;

/** Max plays one user can add per day (IST). ~33 hours of 4-minute songs. */
export const DAILY_PLAY_CAP = 500;

/** Firestore doc ids we generate are slugs; anything else is rejected so a
 *  song id is always safe to use as a map field name. */
const SONG_ID_PATTERN = /^[A-Za-z0-9_-]{1,128}$/;

export class PlayPayloadError extends Error {}

/**
 * Validates the `plays` map sent by the client and returns a sanitized copy.
 * Throws [PlayPayloadError] for malformed input; silently clamps counts.
 */
export function validatePlays(input: unknown): PlayCounts {
  if (input === null || typeof input !== 'object' || Array.isArray(input)) {
    throw new PlayPayloadError('plays must be an object of songId -> count');
  }
  const entries = Object.entries(input as Record<string, unknown>);
  if (entries.length === 0) {
    throw new PlayPayloadError('plays is empty');
  }
  if (entries.length > MAX_SONGS_PER_CALL) {
    throw new PlayPayloadError(
      `at most ${MAX_SONGS_PER_CALL} songs per call`,
    );
  }

  const out: PlayCounts = {};
  for (const [songId, raw] of entries) {
    if (!SONG_ID_PATTERN.test(songId)) {
      throw new PlayPayloadError(`invalid song id: ${songId.slice(0, 40)}`);
    }
    if (typeof raw !== 'number' || !Number.isInteger(raw) || raw < 1) {
      throw new PlayPayloadError(`invalid count for ${songId}`);
    }
    out[songId] = Math.min(raw, MAX_PLAYS_PER_SONG_PER_CALL);
  }
  return out;
}

export function totalPlays(counts: PlayCounts): number {
  return Object.values(counts).reduce((sum, n) => sum + n, 0);
}

/**
 * Trims [requested] so the user's day total never exceeds [cap].
 * Songs are admitted in the order given until the remaining budget runs out.
 */
export function applyDailyQuota(
  requested: PlayCounts,
  usedToday: number,
  cap: number = DAILY_PLAY_CAP,
): { accepted: PlayCounts; acceptedTotal: number; dropped: number } {
  let budget = Math.max(0, cap - usedToday);
  const accepted: PlayCounts = {};
  let acceptedTotal = 0;
  for (const [songId, n] of Object.entries(requested)) {
    if (budget <= 0) break;
    const take = Math.min(n, budget);
    accepted[songId] = take;
    acceptedTotal += take;
    budget -= take;
  }
  return {
    accepted,
    acceptedTotal,
    dropped: totalPlays(requested) - acceptedTotal,
  };
}

/** Adds [b] into a copy of [a]. */
export function mergeCounts(a: PlayCounts, b: PlayCounts): PlayCounts {
  const out: PlayCounts = { ...a };
  for (const [songId, n] of Object.entries(b)) {
    out[songId] = (out[songId] ?? 0) + n;
  }
  return out;
}

/** Calendar day key in India Standard Time (UTC+05:30), e.g. `2026-10-13`. */
export function istDayKey(date: Date): string {
  const ist = new Date(date.getTime() + 330 * 60 * 1000);
  return ist.toISOString().slice(0, 10);
}

/** Day keys for the last [days] days, newest first, ending at [now]. */
export function recentDayKeys(now: Date, days: number): string[] {
  const keys: string[] = [];
  for (let i = 0; i < days; i++) {
    keys.push(istDayKey(new Date(now.getTime() - i * 24 * 60 * 60 * 1000)));
  }
  return keys;
}

/**
 * Ranks songs by recent plays with exponential decay: today's plays count
 * fully, yesterday's × [decay], the day before × decay², and so on.
 * [dailyCounts] is newest first. Returns song ids, best first.
 */
export function rankTrending(
  dailyCounts: PlayCounts[],
  decay = 0.7,
): string[] {
  const scores: Record<string, number> = {};
  dailyCounts.forEach((day, age) => {
    const weight = Math.pow(decay, age);
    for (const [songId, n] of Object.entries(day)) {
      scores[songId] = (scores[songId] ?? 0) + n * weight;
    }
  });
  return Object.entries(scores)
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .map(([songId]) => songId);
}
