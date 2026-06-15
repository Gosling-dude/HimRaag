/**
 * Canonical metadata validation + normalization for the import pipeline.
 *
 * Mirrors `lib/core/validation/metadata_validator.dart`. Used by import.js and
 * validate_catalog.js. Pure functions (no Firestore) except the optional
 * network reachability checks, which are gated behind an explicit flag.
 */

'use strict';

const {
  LICENSES,
  APPROVAL_STATUSES,
  REGIONS,
  LANGUAGES,
  GENRES,
} = require('./constants');

// ─── Slug ──────────────────────────────────────────────────────────────────

function slugify(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '') // strip combining diacritics
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

/** Deterministic song id from artist + title, stable across re-imports. */
function songId(artistName, title) {
  return `song_${slugify(artistName)}__${slugify(title)}`.replace(/-/g, '_');
}

function artistId(name) {
  return `artist_${slugify(name)}`.replace(/-/g, '_');
}

function albumId(artistName, title) {
  return `album_${slugify(artistName)}__${slugify(title)}`.replace(/-/g, '_');
}

// ─── Normalization ───────────────────────────────────────────────────────────

/** Case-insensitive canonicalization against an allowed list. Returns the
 *  canonical value, or the original trimmed input if no match (caller validates). */
function canonicalize(value, allowed) {
  const v = String(value || '').trim();
  const hit = allowed.find((a) => a.toLowerCase() === v.toLowerCase());
  return hit || v;
}

// ─── URL checks ──────────────────────────────────────────────────────────────

function looksLikeUrl(value) {
  return /^https?:\/\/.+/i.test(String(value || ''));
}

async function checkUrlReachable(url, expectContentTypePrefix) {
  try {
    let res = await fetch(url, { method: 'HEAD', redirect: 'follow' });
    // Some CDNs don't support HEAD — fall back to a ranged GET.
    if (res.status === 405 || res.status === 501) {
      res = await fetch(url, {
        method: 'GET',
        headers: { Range: 'bytes=0-0' },
        redirect: 'follow',
      });
    }
    const ct = res.headers.get('content-type') || '';
    const ok = res.ok || res.status === 206;
    const typeOk =
      !expectContentTypePrefix || ct.toLowerCase().startsWith(expectContentTypePrefix);
    return {
      ok: ok && typeOk,
      status: res.status,
      contentType: ct,
      reason: !ok
        ? `HTTP ${res.status}`
        : !typeOk
        ? `unexpected content-type "${ct}"`
        : null,
    };
  } catch (e) {
    return { ok: false, status: 0, contentType: '', reason: e.message };
  }
}

// ─── Track validation ────────────────────────────────────────────────────────

const REQUIRED_TRACK_FIELDS = [
  'title',
  'artistName',
  'region',
  'language',
  'genre',
  'durationMs',
  'artworkUrl',
  'audioUrl',
  'license',
  'approvalStatus',
];

/**
 * Validate + normalize a single raw track record (plain object from CSV/JSON).
 * Returns { ok, errors, warnings, normalized }. Does NOT touch the network;
 * pass the result to `checkLinks` separately when online checks are desired.
 */
function validateTrack(raw, opts = {}) {
  const errors = [];
  const warnings = [];
  const t = { ...raw };

  // Coerce duration.
  if (typeof t.durationMs === 'string') t.durationMs = parseInt(t.durationMs, 10);
  if (typeof t.releaseYear === 'string') t.releaseYear = parseInt(t.releaseYear, 10);
  if (typeof t.playCount === 'string') t.playCount = parseInt(t.playCount, 10);

  // Required fields.
  for (const f of REQUIRED_TRACK_FIELDS) {
    const val = t[f];
    if (val === undefined || val === null || val === '') {
      errors.push(`missing required field "${f}"`);
    }
  }

  // Normalize taxonomy.
  t.region = canonicalize(t.region, REGIONS);
  t.language = canonicalize(t.language, LANGUAGES);
  t.genre = canonicalize(t.genre, GENRES);

  if (t.region && !REGIONS.includes(t.region)) {
    errors.push(`region "${t.region}" is not an allowed Pahadi region`);
  }
  if (t.language && !LANGUAGES.includes(t.language)) {
    errors.push(`language "${t.language}" is not an allowed language`);
  }
  if (t.genre && !GENRES.includes(t.genre)) {
    warnings.push(`genre "${t.genre}" is not in the standard genre list`);
  }

  // Duration must be a real, positive value (no 00:00 tracks).
  if (!Number.isFinite(t.durationMs) || t.durationMs <= 0) {
    errors.push('durationMs must be a positive number (no 00:00 tracks)');
  }

  // License + rights.
  const lic = LICENSES[t.license];
  if (!lic) {
    errors.push(
      `license "${t.license}" is unknown — rights unclear, track rejected`
    );
  } else {
    t.rightsCleared = lic.cleared;
    if (lic.requiresAttribution && !String(t.attribution || '').trim()) {
      errors.push(`license "${t.license}" requires a non-empty attribution`);
    }
    // Demo content must never be published.
    if (t.license === 'DEMO_ONLY' && t.isPublished === true) {
      errors.push('DEMO_ONLY content cannot be published (isPublished must be false)');
    }
  }

  // Approval status.
  if (t.approvalStatus && !APPROVAL_STATUSES.includes(t.approvalStatus)) {
    errors.push(`approvalStatus "${t.approvalStatus}" is invalid`);
  }

  // URLs (shape only here; reachability is a separate async pass).
  if (t.audioUrl && !looksLikeUrl(t.audioUrl)) {
    errors.push('audioUrl must be an http(s) URL');
  }
  if (t.artworkUrl && !looksLikeUrl(t.artworkUrl)) {
    errors.push('artworkUrl must be an http(s) URL');
  }

  // Lyrics / year are optional but warned when absent (data-quality signal).
  if (!String(t.lyrics || '').trim()) warnings.push('no lyrics provided');
  if (!Number.isFinite(t.releaseYear)) warnings.push('no releaseYear provided');

  // Derived fields.
  t.title = String(t.title || '').trim();
  t.artistName = String(t.artistName || '').trim();
  t.slug = t.slug || slugify(t.title);
  t.id = t.id || songId(t.artistName, t.title);
  t.artistId = t.artistId || artistId(t.artistName);
  if (t.albumTitle) {
    t.albumId = t.albumId || albumId(t.artistName, t.albumTitle);
  } else {
    t.albumId = t.albumId || '';
    t.albumTitle = t.albumTitle || '';
  }
  t.isPublished = t.isPublished === true;
  t.isDownloadable = t.isDownloadable !== false;
  t.playCount = Number.isFinite(t.playCount) ? t.playCount : 0;
  t.tags = Array.isArray(t.tags)
    ? t.tags
    : String(t.tags || '')
        .split(/[;|,]/)
        .map((s) => s.trim())
        .filter(Boolean);

  return { ok: errors.length === 0, errors, warnings, normalized: t };
}

/** Async reachability check for a normalized track. */
async function checkLinks(track) {
  const issues = [];
  const audio = await checkUrlReachable(track.audioUrl, 'audio');
  if (!audio.ok) issues.push(`audioUrl unreachable: ${audio.reason}`);
  const art = await checkUrlReachable(track.artworkUrl, 'image');
  if (!art.ok) issues.push(`artworkUrl unreachable: ${art.reason}`);
  return issues;
}

/**
 * Detect duplicates within a batch. Two tracks collide if they share an id, a
 * slug under the same artist, or a (title|artist) pair. Returns array of
 * { index, with, reason }.
 */
function findDuplicates(tracks) {
  const byId = new Map();
  const byKey = new Map();
  const dups = [];
  tracks.forEach((t, i) => {
    if (byId.has(t.id)) {
      dups.push({ index: i, with: byId.get(t.id), reason: `duplicate id "${t.id}"` });
    } else {
      byId.set(t.id, i);
    }
    const key = `${slugify(t.artistName)}|${slugify(t.title)}`;
    if (byKey.has(key)) {
      dups.push({
        index: i,
        with: byKey.get(key),
        reason: `duplicate title+artist "${t.title}" / "${t.artistName}"`,
      });
    } else {
      byKey.set(key, i);
    }
  });
  return dups;
}

module.exports = {
  slugify,
  songId,
  artistId,
  albumId,
  canonicalize,
  looksLikeUrl,
  checkUrlReachable,
  validateTrack,
  checkLinks,
  findDuplicates,
  REQUIRED_TRACK_FIELDS,
};
