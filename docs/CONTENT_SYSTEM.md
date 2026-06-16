# HimRaag Content System

How catalog content is modelled, validated, imported, moderated, and scaled —
plus how to run the admin/artist dashboards. This system is **free-tier only**
(no Firebase Storage/Blaze; audio + artwork come from external free CDNs).

---

## 1. Data model & schema

Catalog metadata lives in Firestore. Collections:

| Collection     | Purpose                                  | Public read |
|----------------|------------------------------------------|-------------|
| `songs`        | Tracks (the playable unit)               | yes         |
| `albums`       | Album groupings                          | yes         |
| `artists`      | Artist profiles                          | yes         |
| `categories`   | Genre/mood/festival browse tiles         | yes         |
| `submissions`  | Artist-contributor upload requests       | owner+admin |
| `auditLogs`    | Append-only moderation/import trail      | admin only  |

### Song document fields

Core: `title`, `titleLowercase`, `artistId`, `artistName`, `albumId`,
`albumTitle`, `audioUrl`, `artworkUrl`, `durationMs`, `region`, `language`,
`genre`, `releaseYear`, `playCount`, `tags[]`, `lyrics?`, `mood?`.

Content-system fields (added by this system):

| Field            | Type    | Meaning |
|------------------|---------|---------|
| `slug`           | string  | URL-safe key derived from title |
| `license`        | string  | One of the license taxonomy (below) |
| `attribution`    | string  | Exact attribution text, stored verbatim |
| `licenseUrl?`    | string  | Link to the license |
| `sourceUrl?`     | string  | Where the audio came from |
| `approvalStatus` | string  | `demo` / `pending` / `approved` / `rejected` |
| `isApproved`     | bool    | Mirror of `approvalStatus == 'approved'` (back-compat) |
| `isPublished`    | bool    | **Public visibility gate.** Demo = always false |
| `rightsCleared`  | bool    | Derived from the license |
| `isDownloadable` | bool    | Offline download allowed |
| `submittedBy?`   | string  | UID of the submitter (artist workflow) |
| `updatedAt`      | ts      | Server timestamp on every write |

`albums` and `artists` carry the same licensing/approval fields (artists use
`rightsNote` + `ownerUid` instead of `attribution`/`submittedBy`).

The canonical enums are defined once in
`lib/core/constants/content_constants.dart` (Dart) and mirrored in
`scripts/lib/constants.js` (Node). **Keep the two in sync.**

### License taxonomy

| Wire value           | Rights cleared | Attribution required |
|----------------------|----------------|----------------------|
| `DEMO_ONLY`          | no             | no |
| `PUBLIC_DOMAIN`      | yes            | no |
| `CC0`                | yes            | no |
| `CC-BY`              | yes            | yes |
| `CC-BY-SA`           | yes            | yes |
| `PROVIDED`           | yes            | no |
| `PERMISSION_GRANTED` | yes            | yes |
| `LICENSED`           | yes            | no |

Validation **rejects** any unknown license (rights unclear → not ingested), and
**rejects publishing** anything whose license is not cleared.

---

## 2. Demo content vs. public content

The seed catalog is **demo-only** (`license=DEMO_ONLY`, `approvalStatus=demo`,
`isPublished=false`). It uses traditional/public-domain folk **titles** credited
to `Traditional (<region>)` or clearly-fictional `(Demo)` ensembles — **no real
living artists** — with royalty-free CC audio and placeholder artwork. The exact
`attribution` field states the audio is a placeholder, not the original
recording.

### How demo content stays testable but never ships

`lib/core/config/app_config.dart` exposes `AppConfig.includeDemoContent`:

* **Debug builds** → demo content included (team can test on the seed).
* **Release builds** → demo content excluded.
* Override: `--dart-define=HIMRAAG_INTERNAL=true|false`.

The consumer providers apply `visibleToConsumers()`
(`lib/data/catalog_visibility.dart`), which drops `DEMO_ONLY` items when the flag
is off. The admin dashboard is **not** filtered — moderators see everything.

> Before public launch, either purge demo docs or ship with
> `HIMRAAG_INTERNAL=false`. The long-term public gate is `isPublished == true`.

---

## 3. Bulk import pipeline (Node, `scripts/`)

All scripts reuse the `firebase-admin` SDK already in `scripts/node_modules`.

```
scripts/
  lib/constants.js        canonical enums (mirror of Dart)
  lib/validator.js        validation + slug + dedup + URL checks
  import.js               CSV / JSON / folder import (+ --commit)
  generate_demo_catalog.js builds the demo catalog JSON
  validate_catalog.js     live catalog health scan
  set_claims.js           grant admin/artist dashboard access
  seed_firestore.js       generate + import orchestrator
```

### Validate then commit (dry-run is the default)

```bash
# Offline validation (no creds, no writes):
node scripts/import.js --json scripts/seed_data/catalog.json --no-network

# Commit to Firestore:
GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json \
  node scripts/import.js --json scripts/seed_data/catalog.json --commit
```

Input formats:

* `--json <file>` — `{ artists, albums, songs }` or a bare song array.
* `--csv <file>` — one song per row; headers match song fields.
* `--folder <dir>` — a directory of `<track>/meta.json` sidecar files. Audio
  tags are **not** read (keeps deps light); put metadata in `meta.json`.

What import does for every record: required-field check, region/language/genre
normalization, license check, slug generation, duplicate detection (id and
title+artist), URL shape + reachability (skippable with `--no-network`). It
derives `artists`/`albums` from songs when not supplied, writes in batches, and
appends an `auditLogs` entry.

### Seeding (repeatable)

```bash
# regenerate the demo catalog + dry-run validate:
node scripts/seed_firestore.js --no-network

# write the demo catalog to Firestore:
GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/seed_firestore.js --commit
```

Ids are deterministic, so re-seeding is idempotent (upsert by id).

### Catalog health scan

```bash
GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/validate_catalog.js
```

Reports missing artwork/lyrics, zero-duration, broken audio/artwork URLs,
duplicates, orphan artist/album refs, and rights issues (published-but-uncleared).
This is the same report the dashboard's **Data Quality** view shows.

---

## 4. Dashboards (Flutter Web)

A separate web target sharing the consumer app's domain models + datasources.

```bash
# run locally:
flutter run   -d chrome -t lib/admin/main_admin.dart
# build for hosting:
flutter build web        -t lib/admin/main_admin.dart
```

> The web target needs a registered Firebase **Web app**. Finalize
> `lib/firebase_options.dart`'s `web` block with `flutterfire configure
> --platforms=web` (placeholders are committed so the project compiles).

### Granting access (custom claims)

```bash
GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json \
  node scripts/set_claims.js --email you@example.com --role admin   # or artist
```

The user must sign out/in for the claim to take effect. The same claims gate the
Firestore security rules.

### Admin dashboard
Overview (counts + data-quality + needs-review) · Songs/Albums/Artists tables
with search + filter (region / language / approval status) · create/edit (full
metadata form with client-side validation) · approve/reject · batch CSV/JSON
import (validate → preview → commit) · **Metadata Review** (bulk-assign artist /
album / language / region / genre to many tracks) · Data Quality · Audit log.
Every mutation writes an audit entry.

### Artist dashboard
Profile + bio + rights-note editing (own doc only) · album list · track list ·
submission status · "New submission" workflow (creates a `pending` submission an
admin then reviews). The artist cannot self-approve or change moderation fields
(enforced by rules).

---

## 5. Security model

`firestore.rules`:

* Catalog (`songs`/`albums`/`artists`/`categories`) — public read; create/delete
  admin-only; artists may update **their own** profile (claim `role==artist` +
  matching `ownerUid`) but not moderation fields.
* `submissions` — artist creates own (`status=pending`); owner reads own; admin
  reads/moderates all.
* `auditLogs` — admin read; create via admin/SDK; never update/delete.

---

## 6. Scaling to a real licensed catalog

The schema is designed so demo content can be swapped for licensed content
**without app changes**:

1. Prepare records (CSV/JSON) with a cleared license
   (`PROVIDED`/`LICENSED`/`PERMISSION_GRANTED`/`CC-*`) and exact `attribution`.
2. Import via the dashboard or `scripts/import.js` (same validation runs).
3. Approve (sets `approvalStatus=approved`, `isApproved=true`, `isPublished=true`).
4. Remove demo docs (filter `license==DEMO_ONLY`) or simply ship with
   `HIMRAAG_INTERNAL=false` so they never appear.

Because ids are deterministic and writes are upserts, re-imports are safe and the
approval workflow, region/language requirements, audit log, and moderation gates
all stay in force at any scale.

---

## 7. Local-audio import (bundled assets)

For audio files you hold on disk (no hosting/CDN), the local-audio pipeline
bundles them into the app and registers them in the catalog. Audio plays through
the **unchanged** player: `audioUrl` is an `asset:///assets/audio/<file>` URL,
which just_audio resolves natively (the validator accepts `asset://`/`file://`
in addition to `http(s)`).

### One-command workflow

```bash
# 1. drop files into a folder, then (dry-run: scan + bundle + validate):
node scripts/seed_imported.js "D:\path\to\music"

# 2. write to Firestore (or paste the catalog into Admin → Import):
GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/seed_imported.js --commit
```

It chains three steps (each runnable standalone):

1. `scan_audio.js <folder>` — recursively scans `.mp3/.wav/.m4a/.aac/.flac`,
   decodes real durations + embedded tags (via `music-metadata`), and writes
   `scripts/seed_data/scan_result.json` plus `IMPORT_REPORT.md` /
   `METADATA_QUALITY_REPORT.md`.
2. `generate_import_catalog.js` — copies each file to `assets/audio/<slug>.<ext>`
   and emits `scripts/seed_data/imported_catalog.json`.
3. `import.js --json … --no-network` — validates (and `--commit` writes).

### Placeholder policy & review

Files with no usable tags are imported with safe placeholders: `title` from the
filename, `artistName="Unknown Artist"`, `albumTitle="Imported Recordings"`,
`region="Needs Review"`, `language="Needs Review"`, `genre="Folk"`. They are
imported **approved + visible** (so they appear in Home/Search/Library
immediately) and tagged `needs-metadata-review`. The dashboard's **Metadata
Review** section lists them and offers bulk-assign of artist/album/language/
region/genre — assigning real values clears the review tag automatically. No
manual Firestore editing is required.
