#!/usr/bin/env node
/**
 * Google Play Developer API helper for HimRaag. No dependencies (Node 18+).
 *
 *   node scripts/release/play_publish.mjs status [--json]
 *   node scripts/release/play_publish.mjs upload --aab <file.aab> --track alpha \
 *        --notes store/play/release-notes/<versionCode>/en-GB.txt \
 *        --expect-version-code <versionCode> [--release-name "1.0.2 (3)"] \
 *        [--replace-draft] [--commit] [--changes-not-sent-for-review]
 *
 * `status` is read-only: it lists the tracks, their releases and the highest
 * version code Play has seen.
 *
 * `upload` without --commit is a dry run: it authenticates, opens an edit,
 * checks the version code and the target track, prints the plan and discards
 * the edit. Nothing is uploaded.
 *
 * `upload --commit` uploads the bundle, verifies Play read the expected
 * version code and checksum, puts a DRAFT release with the release notes on
 * the track, validates and commits the edit. It never rolls a release out and
 * never sends anything for review — that stays a deliberate step in Play
 * Console. Production is refused unless --allow-production is passed, and even
 * then only a draft is created.
 *
 * Credentials: a Google Cloud service-account JSON key whose email has been
 * invited in Play Console → Users and permissions with access to HimRaag only.
 * Path from HIMRAAG_PLAY_SA_KEY (default ~/.config/himraag/play-publisher.json).
 * The key must live outside this (public) repository. Its private key is never
 * printed; only the service-account email is.
 */
import { createHash, createSign } from 'node:crypto';
import { existsSync, readFileSync, realpathSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const PACKAGE = 'com.sumitchauhan.himraag';
const API = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE}`;
const UPLOAD_API = `https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/${PACKAGE}`;
// Fixed on purpose: the signed assertion is only ever sent to Google, whatever
// the key file says.
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const DEFAULT_KEY = path.join(homedir(), '.config', 'himraag', 'play-publisher.json');
// Default store-listing language in Play Console (Store listings → Default).
const NOTES_LANGUAGE = 'en-GB';
const MAX_NOTES_CHARS = 500;

/** A failure with a clear message and optional "how to fix" lines. */
class Abort extends Error {
  constructor(message, ...hints) {
    super(message);
    this.hints = hints;
  }
}

function parseArgs(argv) {
  const [command, ...rest] = argv;
  const flags = {};
  for (let i = 0; i < rest.length; i++) {
    const arg = rest[i];
    if (!arg.startsWith('--')) throw new Abort(`Unexpected argument: ${arg}`);
    const next = rest[i + 1];
    if (next === undefined || next.startsWith('--')) {
      flags[arg.slice(2)] = true;
    } else {
      flags[arg.slice(2)] = next;
      i++;
    }
  }
  return { command, flags };
}

// ── Credentials ─────────────────────────────────────────────────────────────

function loadServiceAccount() {
  const keyPath = process.env.HIMRAAG_PLAY_SA_KEY || DEFAULT_KEY;
  if (!existsSync(keyPath)) {
    throw new Abort(
      `No service-account key at ${keyPath}.`,
      'Set up Play Developer API access as described in scripts/release/README.md,',
      'then save the key there or point HIMRAAG_PLAY_SA_KEY at it (outside this repo).',
    );
  }
  const real = realpathSync(keyPath);
  if (real === REPO_ROOT || real.startsWith(REPO_ROOT + path.sep)) {
    throw new Abort(
      'The service-account key is inside the repository, which is public.',
      'Move it to ~/.config/himraag/ (chmod 600) and delete the copy in the repo.',
    );
  }
  if ((statSync(real).mode & 0o077) !== 0) {
    console.warn(`! ${keyPath} is readable by other users. Run: chmod 600 "${keyPath}"`);
  }
  let key;
  try {
    key = JSON.parse(readFileSync(real, 'utf8'));
  } catch {
    throw new Abort(`${keyPath} is not valid JSON.`);
  }
  if (key.type !== 'service_account' || !key.client_email || !key.private_key) {
    throw new Abort(`${keyPath} is not a Google service-account key.`);
  }
  return key;
}

async function getAccessToken(key) {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const unsigned = `${encode({ alg: 'RS256', typ: 'JWT' })}.${encode({
    iss: key.client_email,
    scope: SCOPE,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  })}`;
  const signature = createSign('RSA-SHA256')
    .update(unsigned)
    .sign(key.private_key)
    .toString('base64url');

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${signature}`,
    }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || !body.access_token) {
    throw new Abort(
      `Google refused a token for ${key.client_email} ` +
        `(HTTP ${res.status}: ${body.error_description || body.error || 'no details'}).`,
      'Check that the key still exists and is enabled in Google Cloud → IAM → Service accounts.',
    );
  }
  return body.access_token;
}

// ── API ─────────────────────────────────────────────────────────────────────

class PlayApi {
  constructor(token) {
    this.token = token;
  }

  async request(method, url, { json, body, headers = {} } = {}) {
    const res = await fetch(url, {
      method,
      headers: {
        authorization: `Bearer ${this.token}`,
        ...(json !== undefined ? { 'content-type': 'application/json' } : {}),
        ...headers,
      },
      body: json !== undefined ? JSON.stringify(json) : body,
    });
    const text = await res.text();
    let data = null;
    try {
      data = text ? JSON.parse(text) : null;
    } catch {
      data = text;
    }
    if (!res.ok) {
      const err = new Error(data?.error?.message || `HTTP ${res.status} from ${method} ${url}`);
      err.status = res.status;
      throw err;
    }
    return { data, res };
  }

  async openEdit() {
    return (await this.request('POST', `${API}/edits`, { json: {} })).data.id;
  }

  async deleteEdit(editId) {
    await this.request('DELETE', `${API}/edits/${editId}`).catch(() => {});
  }

  async tracks(editId) {
    return (await this.request('GET', `${API}/edits/${editId}/tracks`)).data?.tracks ?? [];
  }

  async track(editId, track) {
    return (await this.request('GET', `${API}/edits/${editId}/tracks/${track}`)).data;
  }

  async versionCodes(editId) {
    const [bundles, apks] = await Promise.all([
      this.request('GET', `${API}/edits/${editId}/bundles`),
      this.request('GET', `${API}/edits/${editId}/apks`),
    ]);
    return [...(bundles.data?.bundles ?? []), ...(apks.data?.apks ?? [])]
      .map((artifact) => Number(artifact.versionCode))
      .sort((a, b) => a - b);
  }

  /** Resumable upload; returns Play's Bundle record (versionCode, sha256). */
  async uploadBundle(editId, bytes) {
    const start = await this.request(
      'POST',
      `${UPLOAD_API}/edits/${editId}/bundles?uploadType=resumable`,
      {
        json: {},
        headers: {
          'x-upload-content-type': 'application/octet-stream',
          'x-upload-content-length': String(bytes.length),
        },
      },
    );
    const session = start.res.headers.get('location');
    if (!session) throw new Error('Play did not open an upload session.');
    const done = await this.request('PUT', session, {
      body: bytes,
      headers: { 'content-type': 'application/octet-stream' },
    });
    return done.data;
  }

  async putTrack(editId, track, releases) {
    await this.request('PUT', `${API}/edits/${editId}/tracks/${track}`, {
      json: { track, releases },
    });
  }

  async validate(editId) {
    await this.request('POST', `${API}/edits/${editId}:validate`);
  }

  async commit(editId, changesNotSentForReview) {
    const query = changesNotSentForReview ? '?changesNotSentForReview=true' : '';
    await this.request('POST', `${API}/edits/${editId}:commit${query}`);
  }
}

/** Opens an edit, runs [fn], and discards the edit unless [fn] committed it. */
async function withEdit(api, fn) {
  const editId = await api.openEdit();
  const state = { committed: false };
  try {
    return await fn(editId, state);
  } finally {
    if (!state.committed) await api.deleteEdit(editId);
  }
}

function describeRelease(release) {
  const codes = (release.versionCodes ?? []).join(', ') || 'no bundles';
  const fraction = release.userFraction ? ` @ ${release.userFraction * 100}%` : '';
  return `${release.status}${fraction} "${release.name ?? '(unnamed)'}" [${codes}]`;
}

/** Turns common API errors into an Abort with the fix. */
function explain(err, serviceAccount) {
  if (err instanceof Abort) return err;
  const message = err.message || String(err);
  if (err.status === 401 || err.status === 403 || /permission|caller does not have/i.test(message)) {
    return new Abort(
      `Play refused the request: ${message}`,
      `In Play Console → Users and permissions, check that ${serviceAccount} is invited`,
      'with access to HimRaag: "View app information (read-only)" and "Release apps to testing',
      'tracks". A new invitation can take some time to apply.',
    );
  }
  if (err.status === 404 && /package/i.test(message)) {
    return new Abort(
      `Play does not show ${PACKAGE} to ${serviceAccount}: ${message}`,
      'Grant the service account access to the HimRaag app in Play Console.',
    );
  }
  if (/status draft may be created on draft app/i.test(message)) {
    return new Abort(
      message,
      'HimRaag has never been published, so Play only accepts draft releases.',
      'Upload as a draft, then review and roll it out in Play Console.',
    );
  }
  if (/version ?code.*(already|used)/i.test(message)) {
    return new Abort(message, 'Increase the build number in pubspec.yaml and rebuild.');
  }
  if (/changesNotSentForReview/i.test(message)) {
    return new Abort(
      message,
      'Re-run with --changes-not-sent-for-review, then send the changes for review in Play Console.',
    );
  }
  return new Abort(message);
}

// ── Commands ────────────────────────────────────────────────────────────────

async function status(api, key, flags) {
  return withEdit(api, async (editId) => {
    const [tracks, codes] = await Promise.all([api.tracks(editId), api.versionCodes(editId)]);
    const summary = {
      package: PACKAGE,
      serviceAccount: key.client_email,
      maxVersionCode: codes.length ? codes[codes.length - 1] : 0,
      versionCodes: codes,
      tracks: tracks.map((t) => ({
        track: t.track,
        releases: (t.releases ?? []).map((r) => ({
          name: r.name,
          status: r.status,
          versionCodes: (r.versionCodes ?? []).map(Number),
          userFraction: r.userFraction,
        })),
      })),
    };
    if (flags.json) {
      console.log(JSON.stringify(summary, null, 2));
      return;
    }
    console.log(`${PACKAGE} — read as ${key.client_email}`);
    console.log(`Version codes in Play: ${codes.join(', ') || 'none'} (highest ${summary.maxVersionCode})`);
    for (const t of tracks) {
      const releases = t.releases ?? [];
      console.log(`  ${t.track}: ${releases.length ? releases.map(describeRelease).join('; ') : 'no releases'}`);
    }
  });
}

async function upload(api, key, flags) {
  const aab = flags.aab;
  if (typeof aab !== 'string' || !aab.endsWith('.aab') || !existsSync(aab)) {
    throw new Abort('--aab must point to an existing .aab file.');
  }
  const track = typeof flags.track === 'string' ? flags.track : 'alpha';
  if (track === 'production' && !flags['allow-production']) {
    throw new Abort(
      'Refusing to touch the production track.',
      'Production releases need explicit approval; promote a tested release in Play Console.',
    );
  }
  const expected = Number(flags['expect-version-code']);
  if (!Number.isInteger(expected) || expected < 1) {
    throw new Abort('--expect-version-code <n> is required (the versionCode inside the bundle).');
  }
  if (typeof flags.notes !== 'string' || !existsSync(flags.notes)) {
    throw new Abort('--notes must point to the release-notes file.');
  }
  const notes = readFileSync(flags.notes, 'utf8').trim();
  if (!notes) throw new Abort(`${flags.notes} is empty.`);
  if ([...notes].length > MAX_NOTES_CHARS) {
    throw new Abort(`${flags.notes} is ${[...notes].length} characters; Play allows ${MAX_NOTES_CHARS}.`);
  }
  const releaseName = typeof flags['release-name'] === 'string' ? flags['release-name'] : String(expected);
  const bytes = readFileSync(aab);
  const sha256 = createHash('sha256').update(bytes).digest('hex');

  return withEdit(api, async (editId, state) => {
    const codes = await api.versionCodes(editId);
    const highest = codes.length ? codes[codes.length - 1] : 0;
    if (expected <= highest) {
      throw new Abort(
        `Version code ${expected} is not higher than ${highest}, the highest already in Play.`,
        `Set the pubspec.yaml build number to ${highest + 1} and rebuild.`,
      );
    }

    const current = await api.track(editId, track);
    const releases = current?.releases ?? [];
    const drafts = releases.filter((r) => r.status === 'draft');
    console.log(`Track ${track}: ${releases.length ? releases.map(describeRelease).join('; ') : 'no releases'}`);
    if (drafts.length && !flags['replace-draft']) {
      throw new Abort(
        `Track ${track} already has a draft release (${drafts.map(describeRelease).join('; ')}).`,
        'Inspect it in Play Console. If it should be replaced, re-run with --replace-draft.',
      );
    }

    const release = {
      name: releaseName,
      versionCodes: [String(expected)],
      status: 'draft',
      releaseNotes: [{ language: NOTES_LANGUAGE, text: notes }],
    };
    console.log(
      `Plan: upload ${path.basename(aab)} (${(bytes.length / 1048576).toFixed(1)} MB, sha256 ${sha256.slice(0, 12)}…)` +
        ` as version code ${expected}, then put a DRAFT release "${releaseName}" on ${track}` +
        (drafts.length ? ` replacing ${drafts.length} existing draft release(s).` : '.'),
    );
    if (!flags.commit) {
      console.log('Dry run: nothing was uploaded or changed. Re-run with --commit to do it.');
      return;
    }

    console.log('Uploading…');
    const bundle = await api.uploadBundle(editId, bytes);
    if (Number(bundle.versionCode) !== expected) {
      throw new Abort(`Play read version code ${bundle.versionCode}, expected ${expected}. Edit discarded.`);
    }
    if (bundle.sha256 && bundle.sha256.toLowerCase() !== sha256) {
      throw new Abort('Play received a file with a different checksum. Edit discarded.');
    }
    const kept = releases.filter((r) => r.status !== 'draft');
    await api.putTrack(editId, track, [...kept, release]);
    await api.validate(editId);
    await api.commit(editId, Boolean(flags['changes-not-sent-for-review']));
    state.committed = true;
    console.log(`✓ Version code ${expected} uploaded and saved as a DRAFT release "${releaseName}" on ${track}.`);
    console.log('  Nothing was rolled out or sent for review. Review it in Play Console → Test and release.');
  });
}

async function main() {
  const { command, flags } = parseArgs(process.argv.slice(2));
  if (!['status', 'upload'].includes(command)) {
    throw new Abort('Usage: play_publish.mjs status [--json] | upload --aab <file> --track <track> --notes <file> --expect-version-code <n> [--commit]');
  }
  const key = loadServiceAccount();
  const api = new PlayApi(await getAccessToken(key));
  try {
    await (command === 'status' ? status(api, key, flags) : upload(api, key, flags));
  } catch (err) {
    throw explain(err, key.client_email);
  }
}

main().catch((err) => {
  const abort = err instanceof Abort ? err : new Abort(err.message || String(err));
  console.error(`\n✗ ${abort.message}`);
  for (const hint of abort.hints ?? []) console.error(`    ${hint}`);
  process.exitCode = 1;
});
