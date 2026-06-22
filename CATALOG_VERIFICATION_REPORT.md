# HimRaag — Catalog Verification Report

_Generated: 2026-06-15 · Source: `scripts/seed_data/catalog.json` (demo catalog)_

## Scope & status

This report verifies the **catalog content and link health** — the part that can
be verified without live credentials. The requested **live verification** (seed
to Firestore → confirm rendering/playback/downloads in the running app) **was NOT
performed** because the environment has:

- no `GOOGLE_APPLICATION_CREDENTIALS` / service-account key (cannot write Firestore)
- no Application Default Credentials / `gcloud`
- no connected device or emulator / `adb`

Run the commands in **"How to complete live verification"** below to finish
steps 1–3. Nothing in this report is a substitute for on-device confirmation of
playback/downloads.

---

## 1. Catalog totals (will be seeded)

| Item    | Count |
|---------|-------|
| Songs   | **116** |
| Albums  | **12** |
| Artists | **12** |
| Unique audio URLs   | 16 (CC0 pool, reused) |
| Unique artwork URLs | 12 |
| Songs with lyrics   | 12 |

All entries are `license=DEMO_ONLY`, `approvalStatus=demo`, `isPublished=false`
(internal testing only — never public).

## 2. Region coverage (all 4 mandatory regions present)

| Region    | Songs |
|-----------|-------|
| Garhwali  | 24 |
| Kumaoni   | 24 |
| Himachali | 20 |
| Jaunsari  | 16 |
| Kinnauri  | 16 |
| Sirmauri  | 16 |

## 3. Broken-items check (live HTTP reachability)

Every unique audio and artwork URL was fetched:

| Check                     | Result |
|---------------------------|--------|
| Broken audio URLs         | **0 / 16** ✅ |
| Broken artwork URLs       | **0 / 12** ✅ |
| Zero / missing duration   | **0 / 116** ✅ |
| Missing artwork           | **0 / 116** ✅ |

Audio resolves as `audio/mpeg`, artwork as `image/jpeg` — i.e. every track is
playable at the source and every cover loads. (Reproduce:
`node scripts/verify_catalog_links.js`.)

## 4. Artists (12)

| Artist | Region | Songs |
|--------|--------|-------|
| Traditional (Garhwali) | Garhwali | 12 |
| HimRaag Demo Ensemble | Garhwali | 12 |
| Traditional (Kumaoni) | Kumaoni | 12 |
| Kumaoni Heritage Voices (Demo) | Kumaoni | 12 |
| Traditional (Jaunsari) | Jaunsari | 8 |
| Jaunsar Bawar Folk Group (Demo) | Jaunsari | 8 |
| Traditional (Himachali) | Himachali | 10 |
| Himachali Naati Collective (Demo) | Himachali | 10 |
| Traditional (Kinnauri) | Kinnauri | 8 |
| Kinnaur Demo Folk Group | Kinnauri | 8 |
| Traditional (Sirmauri) | Sirmauri | 8 |
| Sirmaur Folk Project (Demo) | Sirmauri | 8 |

(No real living artists — demo/placeholder identities only.)

## 5. Albums (12)

Two volumes per region — `<Region> Folk Treasures (Demo) Vol. 1/2` — 8–12 tracks
each, one per demo artist.

## 6. Songs with lyrics (lyrics view test data)

Bedu Pako Baramasa · Nyoli · Jaunsari Naati · Himachali Naati · Kayang ·
Sirmauri Naati (one iconic title per region; clearly marked demo placeholders).

---

## How to complete live verification (steps 1–3)

```bash
# 0. Get a service-account key: Firebase Console → Project Settings →
#    Service Accounts → Generate new private key  (save as sa.json)

# 1. SEED Firestore
GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/seed_firestore.js --commit

# 2. Confirm catalog health on the live DB (broken links, orphans, rights)
GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/validate_catalog.js

# 3. Run the app with demo content visible, on a device/emulator
flutter run --dart-define=HIMRAAG_INTERNAL=true
```

Then walk **`QA_CHECKLIST.md` section D** to confirm in-app: Home loads songs,
artists load, albums load, search finds songs (try "bedu"), playback starts,
seek/next/previous work, background playback, and offline download.

> Note: the consumer app reads from Firestore at runtime. Until step 1 is run the
> app will show an empty catalog — that is expected, not a bug.
