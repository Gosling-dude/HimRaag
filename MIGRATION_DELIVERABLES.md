# HimRaag — R2 + Firestore Migration Deliverables

_Generated: 2026-06-18_

## Headline

The 19 local Pahadi tracks now stream from **Cloudflare R2** with metadata in
**Firestore (`himraag-prod`)**. Bundled MP3s were removed, shrinking the release
build from **126.6 MB → 53.9 MB APK / 27.1 MB AAB**. Imported content is visible
in-app and queued for owner review in the Admin Dashboard.

## Counts

| Deliverable | Value |
|---|---|
| Imported songs | **19** |
| Artists (imported) | **11** (10 identified + 1 `Unknown Artist` placeholder) |
| Albums (imported) | **11** |
| Firestore — `songs` | 29 total (**19 imported** + 10 pre-existing demo) |
| Firestore — `artists` | 16 total (**11 imported** + 5 pre-existing) |
| Firestore — `albums` | 14 total (**11 imported** + 3 pre-existing) |
| Firestore — `auditLogs` | +1 `bulk_import` entry |
| R2 objects (bucket `himraag-audio`) | **60** — 19 `audio/` + 19 `artwork/` + 11 `artists/` + 11 `albums/` |
| R2 public-URL verification | **19/19 audio + 19/19 artwork → HTTP 200/206** |

## Build artifacts

| Item | Value |
|---|---|
| Branch | `feat/content-system-and-seed` |
| Commit | `981c03fc10bea41e61c70d9d1b23bd5ca78fa5bb` |
| APK path | `build/app/outputs/flutter-apk/app-release.apk` |
| APK size | **53.93 MB** (56,550,777 bytes) — was 126.6 MB |
| AAB path | `build/app/outputs/bundle/release/app-release.aab` |
| AAB size | **27.13 MB** (28,447,148 bytes) |
| `flutter analyze` | No issues |
| `flutter test` | 11/11 passing |

## Architecture

```
App start → assets/catalog/imported_catalog.json (metadata) ⊕ Firestore merge
         → audioUrl = https://pub-…r2.dev/audio/<slug>.mp3
         → just_audio AudioSource.uri streams from Cloudflare R2
```
- Consumer visibility gates on `license != DEMO_ONLY`; imported tracks are
  `LICENSED` → visible immediately, while `approvalStatus=pending` +
  `reviewRequired=true` in Firestore queues them for the Admin → Metadata Review.
- `just_audio` needed no change — it already streams `https://` sources.

## Pipeline (reproducible)

```bash
node scripts/scan_audio.js "D:\Personal Projects\HimRaag\music"   # Phase 1
node scripts/generate_audit_report.js                              # AUDIO_AUDIT_REPORT.md
node scripts/enrich_metadata.js                                    # Phase 2 → METADATA_ENRICHMENT_REPORT.md
node scripts/r2_upload.js                                          # Phase 3 → R2_UPLOAD_REPORT.md
node scripts/generate_import_catalog.js                            # catalog + firestore_import.json
GOOGLE_APPLICATION_CREDENTIALS=<sa.json> \
  node scripts/import.js --json scripts/seed_data/firestore_import.json --commit   # Phase 4
GOOGLE_APPLICATION_CREDENTIALS=<sa.json> node scripts/verify_e2e.js                # Phase 7
flutter build apk --release && flutter build appbundle --release                   # Phase 8
```

## Reports generated

- `AUDIO_AUDIT_REPORT.md` — per-file technical + tag audit (Phase 1)
- `METADATA_ENRICHMENT_REPORT.md` — per-field value/source/confidence (Phase 2)
- `R2_UPLOAD_REPORT.md` — object keys + public URLs + 200 verification (Phase 3)
- `E2E_VERIFICATION_REPORT.md` — 5 songs traced source→R2→Firestore→playback (Phase 7)
- `PLAYSTORE_DEPLOYMENT_GUIDE.md` — signing, console, privacy, rollout (Phase 10)

## Metadata enrichment summary

- Embedded tags: **none** on any file → all metadata derived.
- Artists identified from filename/web: Sardar Singh Sharma, Lalit Mohan Joshi,
  Sanjay Sharma, Palak & Hardik, Diksha & Pooja Dhaundiyal, Zorawar Hunk, Rohit
  Chauhan, Thakur Dass Rathi, Jitendra Tomkyal, Surinder Sharma.
- Regions resolved: **17/19** (Kumaoni, Garhwali, Himachali, Jaunsari, Kinnauri);
  2 remain `Needs Review` (Aankhi Micholi, Aaja Aaja).
- Every track flagged `reviewRequired=true` (artwork is a generated placeholder;
  replace + approve in the dashboard).

## Play Store readiness

| Gate | Status |
|---|---|
| Signed release build | ⚠️ Configure upload keystore (guide §1) — not committed |
| AAB produced | ✅ 27.1 MB |
| Privacy policy | ⚠️ Host + link (guide §4) |
| Data safety / content rating | ⚠️ Complete in Console (guide §3) |
| Music rights confirmed | ⚠️ Approve in Metadata Review before publishing |
| App streams from R2 / small artifact | ✅ |

## Security

- `.env/` (Cloudflare R2 keys + Firebase admin SDK) is gitignored; verified not
  staged and absent from git history.
- Scripts load credentials from disk at runtime via `scripts/lib/credentials.js`
  and never print, log, commit, or hardcode secret values.
