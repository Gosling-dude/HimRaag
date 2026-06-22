# HimRaag — Internal Testing QA Checklist

_For the content system + demo catalog. Run before inviting internal testers._

Legend: **[AUTO]** = verifiable locally without device/creds · **[CREDS]** =
needs a Firebase service account · **[DEVICE]** = needs a physical Android device.

---

## A. Pipeline & data (AUTO / CREDS)

- [ ] **[AUTO]** `node scripts/generate_demo_catalog.js` → ≥ 100 songs, all 4
      mandatory regions (Garhwali, Kumaoni, Jaunsari, Himachali). _(Verified: 116 songs / 6 regions.)_
- [ ] **[AUTO]** `node scripts/import.js --json scripts/seed_data/catalog.json --no-network`
      → `0 error(s)`. _(Verified: 116/116 valid.)_
- [ ] **[AUTO]** Every catalog entry is `license=DEMO_ONLY`, `isPublished=false`.
- [ ] **[AUTO]** `flutter analyze` → 0 issues (app + admin). _(Verified.)_
- [ ] **[CREDS]** `node scripts/seed_firestore.js --commit` writes songs/albums/artists + an `auditLogs` entry.
- [ ] **[CREDS]** `node scripts/validate_catalog.js` → no broken audio/artwork URLs, no orphan refs, no rights issues.

## B. Admin dashboard (CREDS)

Run: `flutter run -d chrome -t lib/admin/main_admin.dart` (after `set_claims.js --role admin`).

- [ ] Login with an admin account succeeds; a non-admin sees the "No access" screen.
- [ ] Overview shows correct Songs/Albums/Artists/Pending/Demo counts.
- [ ] Songs table: search by title/artist/album works; region/language/status filters work.
- [ ] Add Song: form validates (rejects bad URL, 0 duration, missing attribution for CC-BY); saves.
- [ ] Edit Song: changes persist; `DEMO_ONLY` cannot be toggled to Published.
- [ ] Approve a demo song → status flips to Approved and it becomes published.
- [ ] Reject / delete a song works (with confirm dialog for delete).
- [ ] Batch Import: paste JSON/CSV → Validate shows per-row errors/warnings/dups → Commit writes only valid rows.
- [ ] Data Quality view matches `validate_catalog.js` output.
- [ ] Audit log records each approve/reject/edit/delete/import.

## C. Artist dashboard (CREDS)

Run with an account given `--role artist` and an artist doc whose `ownerUid` = that uid.

- [ ] Profile + bio + rights note edit and save (moderation fields unchanged).
- [ ] Album list and track list show the artist's content with status chips.
- [ ] "New submission" creates a `pending` submission; it appears in the admin Submissions queue.
- [ ] Admin approve/reject of the submission updates its status.

## D. Playback readiness (DEVICE)

Run the app with demo content visible: `flutter run --dart-define=HIMRAAG_INTERNAL=true`.

- [ ] Home/Search/Region/Album/Artist all populate from the 100+ catalog.
- [ ] Tap a track → audio starts within ~3 s.
- [ ] Duration shows a real value (not 00:00) once loaded.
- [ ] Next / Previous move through the queue.
- [ ] Seek (scrub) jumps to the new position.
- [ ] Background playback continues when the app is minimized; lock-screen controls respond.
- [ ] Favorite a track → appears in Library → Favorites.
- [ ] Recently played updates after playing a track.
- [ ] Download an `isDownloadable` track → plays offline (airplane mode).
- [ ] Lyrics view shows lyrics for tracks that have them (e.g. Bedu Pako Baramasa).

## E. Public-build safety (AUTO / DEVICE)

- [ ] **[AUTO]** Build with `--dart-define=HIMRAAG_INTERNAL=false` → consumer providers drop `DEMO_ONLY`.
- [ ] **[DEVICE]** In that build, Home/Search show **no** demo content (catalog appears empty until licensed content is added).

---

### Verified locally in this pass
`flutter analyze` clean · catalog generates 116 valid songs across 6 regions ·
offline import validation passes 116/116 · audio/artwork pool reachable
(`audio/mpeg`, `image/jpeg`). Live seeding, dashboard auth, and on-device
playback require your Firebase creds + a device (sections B–D).
