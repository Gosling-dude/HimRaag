# Google Play setup status — HimRaag

Last updated: **2026-10-17** · Package: `com.sumitchauhan.himraag` · Developer account: *Sumit_Chauhan_Softwares* (personal, ID 7332424828940777520) · Console app ID 4974333562373588989

This file is the resume point for the Play release work. It supersedes the Play status
in `PLAYSTORE_COMPLIANCE_REPORT.md`, `PLAYSTORE_DEPLOYMENT_GUIDE.md` and `RELEASE_CHECKLIST.md`.

Statuses: **COMPLETED** verified · **WAITING FOR ACCESS** needs permissions · **WAITING FOR MY INPUT**
needs a decision or fact · **BLOCKED** concrete technical issue · **READY FOR APPROVAL** prepared,
awaiting authorization · **RELEASED** publication confirmed.

## Summary

| Area | Status |
|---|---|
| Console access (browser, owner account) | COMPLETED |
| Play Developer API access (service account) | WAITING FOR ACCESS (optional) |
| Music distribution rights | **WAITING FOR MY INPUT — gates every release** |
| Google Sign-In on Play-installed builds | **BLOCKED** — app-signing key not registered in Firebase (fix ready, needs approval) |
| Release bundle 1.0.2 (3) | READY FOR APPROVAL (built, verified, not uploaded) |
| Store listing text and tags | COMPLETED (description saved as a Console draft) |
| App content declarations | WAITING FOR MY INPUT (3 open, 2 to correct) |
| Closed testing – Alpha | WAITING FOR MY INPUT (draft holds stale version code 2) |
| Production access (12 testers × 14 days) | WAITING FOR MY INPUT (0 testers opted in) |
| Repeatable release workflow | COMPLETED (`scripts/release/`) |

## 1. Console access — COMPLETED

| Method | State |
|---|---|
| Browser (Claude in Chrome) | Available. Chrome is signed in as **sc5271027@gmail.com** (Sumit Chauhan), the account **owner** and only user. No extra permission is needed for browser work; every submit, send-for-review or publish action still needs your explicit go-ahead in chat. |
| Play Developer API | Not configured: no service account invited, no key, no `gcloud`/fastlane. Only needed for command-line uploads. |

### Permissions to grant for the API path — WAITING FOR ACCESS

The principal does not exist yet. Create it as described in `scripts/release/README.md`; its email will look
like `himraag-play-publisher@himraag-prod.iam.gserviceaccount.com` — use the exact address Google Cloud shows.

| Principal | Permission label in Play Console (app-level, HimRaag only) | Enables | When |
|---|---|---|---|
| service account | **View app information (read only)** | `play_publish.mjs status`, version-code check, reading tracks | now |
| service account | **Release apps to testing tracks** | upload bundles, create/replace draft releases on internal, closed and open testing | now |
| service account | Manage testing tracks and edit tester lists | not needed — the API cannot edit Play Console email lists, and the workflow doesn't change track settings | no |
| service account | Manage store presence | listing text/graphics through the API (not implemented) | optional, later |
| service account | Release to production, exclude devices and use Play app signing | production releases through the API | only if you decide production should be automated; the workflow refuses production |
| service account | Admin, Edit and delete draft apps, View financial data, Manage orders and subscriptions, Manage policy declarations | — | **never** for this workflow |
| sc5271027@gmail.com | Owner (already has everything) | browser automation | in place |

**Navigation:** Play Console → **Users and permissions** → **Invite new users** → email → **App permissions** →
**Add app** → *HimRaag* → tick the two "now" boxes → **Apply** → leave **Account permissions** empty → **Invite user**.
**Verify:** `node scripts/release/play_publish.mjs status` prints the tracks (alpha draft "2 (1.0.1)", internal "1 (1.0.0)").

## 2. Blockers

### 2.1 Music distribution rights — WAITING FOR MY INPUT

Google Play's Intellectual Property policy removes apps that stream music without rights, and new personal
accounts can be terminated for it. The catalogue (956 songs in Firestore, 697 bundled) carries no evidence of rights:

- `scripts/generate_import_catalog.js` hard-codes `license: 'LICENSED'` and `rightsCleared: true` for **every** imported song,
  and `scripts/polish_catalog.js` sets the same attribution on all of them: *"Traditional Pahadi folk recording."*
- The source file names describe modern commercial recordings: 72 of 697 contain *DJ / cover / remix / latest / official /
  video / lyric*, and 91 end in a converter-style `(256k)` suffix (e.g. `Baadri___Latest_Pahari_Jaunsari_Dj_…`,
  `Ang_Songi___Kinnauri_Cover_Song…`). A traditional folk *composition* can be public domain while the *recording* is not.
- Album covers and artist photos (e.g. "Inder Arya — Singles" in the store screenshots) are commercial artwork.

**I will not upload a release for testers or send anything for review until you confirm** you hold written
permission or licences for the recordings and artwork you ship (or remove what you can't evidence).

### 2.2 Google Sign-In fails on Play-installed builds — BLOCKED (fix READY FOR APPROVAL)

Play re-signs every install with the **app-signing key**. Firebase app *HimRaag (Play)* (`1:39471021909:android:ce23c0c346997c9bf7b9dc`)
has SHA certificates for the debug, old-release and upload keys, but **not** the app-signing key, so "Continue with Google"
returns `DEVELOPER_ERROR (10)` for every tester and for Google's reviewers. Guest mode is unaffected.

Fix (Firebase console → Project settings → Your apps → HimRaag (Play) → **Add fingerprint**, twice):

```
SHA-1   89:5D:6A:78:02:35:95:29:24:B3:CB:32:C5:FD:C4:43:E6:3F:02:B8
SHA-256 23:BF:AA:1B:98:C4:87:98:4A:52:81:17:1A:73:41:1D:38:01:94:B8:F2:89:B2:EF:83:72:E0:AE:2F:70:37:B5
```

These are public certificate fingerprints (Play Console → Protected with Play → App signing). It adds an OAuth client;
no data, rules or existing clients change, and no rebuild is needed. Optionally re-download `google-services.json` afterwards.

## 3. Repository audit

| Check | Result |
|---|---|
| Branch / commit | `migrate-production-package` @ `3b6674d`, large uncommitted working tree (package migration, iOS port, and — since 00:54 on 2026-10-17 — player, queue, Home and song-collection work by another session) |
| Toolchain | Flutter 3.44.9, Dart 3.12.2, JDK 17.0.20, AGP 8.7.3, Gradle 8.12, Kotlin 2.1.0 |
| Package | `applicationId` and `namespace` = `com.sumitchauhan.himraag` — COMPLETED |
| SDK levels | compileSdk 36, targetSdk 36 (meets Play's API 36 requirement), minSdk 24 |
| Release signing | `android/local.properties` → `.env/himraag-upload-keystore.jks`, alias `himraag-upload-2026`; release builds fail without it, so no debug-signed release can be produced — COMPLETED |
| Upload key vs Play | keystore SHA-256 `25:75:AF:8F:77:30:1F:33:DE:B1:31:7C:D7:F7:C5:6E:B5:29:E5:44:6E:99:24:D7:71:E5:68:62:96:EE:FC:A0` = Play's registered upload certificate — COMPLETED |
| Secrets in git | `.env/`, `local.properties`, `google-services.json`, `firebase_options.dart`, keystores are gitignored and **never** appear in history; the keystore password is in no commit or tracked file — COMPLETED. The repo is **public**. |
| Shrinking | R8 minify + resource shrinking on; mapping and native debug symbols ship inside the bundle |
| Manifest | INTERNET, ACCESS_NETWORK_STATE, FOREGROUND_SERVICE(+_MEDIA_PLAYBACK), WAKE_LOCK, POST_NOTIFICATIONS; merged from Firebase Analytics: `AD_ID`, `ACCESS_ADSERVICES_AD_ID`, `ACCESS_ADSERVICES_ATTRIBUTION`, install-referrer. `allowBackup=false`, cleartext off |
| Previous bundle | `build/…/app-release.aab` from 14 Aug: version code 2, upload-key signed, but older than the 16 Oct source edits and code 2 is already in Play → superseded |

### Changes made in this session

| File | Change | Why |
|---|---|---|
| `lib/core/widgets/legal_links.dart` (new) | Privacy Policy, Terms of Service and Delete account links | Play requires the privacy policy **inside the app** and an **in-app path** to request account deletion; neither existed |
| `lib/features/profile/…/profile_screen.dart` | "Privacy & Legal" section (guests see it too) | as above |
| `lib/features/auth/…/sign_in_screen.dart` | the consent line's *Terms of Service* / *Privacy Policy* are now links | users agreed to documents they could not open |
| `lib/core/constants/app_constants.dart` | legal URLs → the live GitHub Pages; added `accountDeletionUrl` | the old `himraag.app` domain does not resolve |
| `pubspec.yaml` / `pubspec.lock` | `version: 1.0.2+3`; `url_launcher` (+ test-only `url_launcher_platform_interface`, `plugin_platform_interface`); `url_launcher_android` pinned to **6.3.25** | 6.3.26+ needs AGP ≥ 8.9.1 and broke the release build on AGP 8.7.3 — remove the pin when AGP is upgraded |
| `test/legal_links_test.dart` (new) | URLs, rendering, each link opens the right page, fallback message | regression guard for the compliance links |
| `.gitignore` | `dist/`, `tester.csv`, `testers.csv*`, `*testers*.csv` | tester emails must never reach the public repo; bundles are large |
| `scripts/release/` (new) | `release_android.sh`, `play_publish.mjs`, `README.md` | repeatable release workflow |
| `store/play/` (new) | listing text, previous Console description, release notes for code 3 | source of truth for Console fields |
| `STORE_LISTING.md` | rewritten to match the app and the Console | old copy claimed 950+ songs, 200+ artists, playlists |

Nothing was committed or pushed. `supportEmail` in `app_constants.dart` still says `support@himraag.app` (dead domain; unused).

## 4. Release bundle 1.0.2 (3) — READY FOR APPROVAL

| | |
|---|---|
| Artifact | `dist/android/1.0.2+3/himraag-1.0.2+3.aab` (65.1 MB) + `.sha256` + `release-summary.json` |
| SHA-256 | `0ffae39bc83b6ea9227ff43066384302f52944cdf45f8a7c4f3260e3d856c083` |
| Package / version | `com.sumitchauhan.himraag`, versionName **1.0.2**, versionCode **3** (Play holds 1 and 2) |
| Signature | `jarsigner`: jar verified; signer SHA-256 = Play upload key; `bundletool validate`: passed; not debuggable |
| Built from | `3b6674d` + the working tree as of 00:50 IST 2026-10-17. **Excludes** the other session's later changes (player, queue, Home, song collections, `audio_session` removal). |
| Release notes | `store/play/release-notes/3/en-GB.txt` |

**Not uploaded**, because the rights question (2.1) is open and the source tree was still changing. Code 3 is unused, so the
final build can still be 3. Decide: ship this snapshot, or rebuild from the current tree once that work is finished
(`scripts/release/release_android.sh --min-version-code 2`, which re-runs every check). The release notes for code 3
describe only the legal links; extend them if the rebuild includes the player and Home changes.

### Tests and build

| Run | Result |
|---|---|
| `flutter analyze` before changes / after changes | no issues / no issues (at build time) |
| `flutter test` before / after | 16/16 / **20/20** passed (`widget_test.dart` is a placeholder) |
| Release build #1 | failed: AAR metadata — `url_launcher_android` 6.3.33 needs AGP ≥ 8.9.1 |
| Release build #2 | succeeded after the pin (4 min 15 s) |
| `integration_test/playback_test.dart` | **not run** — no Android device or emulator on this Mac |
| Current tree (after the other session's edits) | mid-edit it briefly had 4 analyzer issues; at the end of this session `flutter analyze` is clean and `flutter test` passes **40/40** (that session added tests). Not part of the bundle. |

Warnings: Flutter will soon drop Kotlin 2.1.0 (upgrade to ≥ 2.2.20); AGP 8.7.3 forces the `url_launcher_android` pin.
Recommended before rollout: install the bundle on one real phone (internal testing) and smoke-test playback, background audio,
downloads, guest mode and the new links.

## 5. Store listing and assets — COMPLETED

- **Full description** replaced and **saved as a draft** in Console (1,043 chars): removed "Thousands of regional songs" (956 exist),
  "High-quality audio streaming", "Personalized recommendations" and the "Coming soon" list. Old text: `store/play/listings/en-GB/previous/`.
- **Tags:** removed *Audio recorder* and *Musical instrument*; now *Music & audio, Entertainment*.
- Unchanged and accurate: name *HimRaag*, short description, category *Music & audio*, email `himraag.review@gmail.com`,
  website `https://gosling-dude.github.io/himraag-legal/`, privacy policy URL, free.
- Graphics present in Console (icon, feature graphic, 8 phone screenshots reused for tablets); no source files in the repo.
  They show the real app UI, including commercial album artwork (see 2.1).
- Details and field mapping: `STORE_LISTING.md`.

## 6. Policy declarations (App content)

| Declaration | Console | Code reality | Status |
|---|---|---|---|
| Privacy policy | `…/himraag-legal/privacy.html` (HTTP 200) | in-app link added in 1.0.2 | COMPLETED once 1.0.2 ships |
| Ads | "No ads" | no ad SDKs | COMPLETED |
| **Advertising ID** | **not started** — Console: *"You can't rollout releases … until you have completed this declaration"* | `AD_ID` merged in by Firebase Analytics, which collects the advertising ID | WAITING FOR MY INPUT (Q2) |
| **Foreground service permissions** | **not started** | `FOREGROUND_SERVICE_MEDIA_PLAYBACK` for background music; form requires a **video link** | WAITING FOR MY INPUT (Q5) |
| **Content ratings** | completed 7 Aug (ESRB Everyone, PEGI 3, IARC 3+); a second questionnaire is **in progress** | at least one title references alcohol ("Pen De Daru") | WAITING FOR MY INPUT (Q4) |
| Target audience | 13–15, 16–17, 18+ | privacy policy: not for under-13s | COMPLETED |
| Sign-in details (app access) | "restricted", one "Google Play Review Account" login | everything works via **Continue as Guest**; Google sign-in currently broken on Play builds (2.2) | WAITING FOR MY INPUT (Q6) |
| Data safety | see below | mostly right, four mismatches | WAITING FOR MY INPUT (Q3) |
| Account deletion | URL `…/delete-account.html` (email-based request) | in-app link added in 1.0.2 | COMPLETED once 1.0.2 ships |
| Health, Financial features, Government apps | actioned | not applicable | COMPLETED |

**Data safety mismatches** (current answers vs code):

| Data type | Declared | Reality | Proposed |
|---|---|---|---|
| App interactions | collected, **optional** | favourites, recently played, listen counts sync to Firestore for **every** user — guests use Firebase anonymous auth (enabled) — plus Analytics events | collected, **required** |
| In-app search history | collected | not stored or logged anywhere; queries only run the search | remove (or mark ephemeral) |
| Approximate location | not declared | privacy policy says Analytics derives it from IP; Google Analytics documents this | declare: collected, Analytics |
| Name, email, user IDs; crash logs, diagnostics; device or other IDs | declared | accurate (profile-photo URL is also stored) | keep |

The hosted legal pages contradict the code and must be corrected in the `himraag-legal` site (not in this repo):

- privacy.html: *"In guest mode your preferences, favourites and listening history are stored only on your device and are
  never written to our servers"* — guests sign in anonymously (provider enabled), and `ensureUserDoc`, `syncFavorites` and
  `logPlay` write to `users/{uid}`; `firestore.rules` allows it (`isOwner` only needs `request.auth != null`).
- delete-account.html: *"Never signed in? There is nothing to delete"* and *"none of your data left your device"* — same issue;
  guests also need a way to identify their data (the Profile screen shows only the first 14 characters of the user ID).
- delete-account.html: *"In-app deletion (coming in a future release)"* — 1.0.2 adds the in-app link.

## 7. Closed testing and the production-access requirement

| Item | State |
|---|---|
| Closed testing – Alpha | **Inactive**. Draft release "2 (1.0.1)" (version code 2, stale). Setup 3/4: remaining *Preview and confirm*, *Send for review*. |
| Countries | India only — testers elsewhere cannot install |
| Testers | email list *HimRaag Internal Testers*: **5 addresses** (all valid format, gmail.com) — includes **sc5271027@gmail.com** (you) and one that looks like the review account (`hi…w@gmail.com`) |
| Opted in | **0** (dashboard: "0 testers currently opted in") |
| Opt-in link | none yet — Console: "Links will be shown here when you publish your app" |
| Feedback channel | himraag.review@gmail.com |
| Internal testing | **Active**: "1 (1.0.0)", released 13 Aug, same list, link `https://play.google.com/apps/internaltest/4701129479465251167`. Internal testers **do not** count towards production access. |

**Requirement for this account (shown in its Console, matches Google's help for personal accounts created after
13 Nov 2023):** publish a closed test, have **at least 12 testers opted in**, each **continuously for the 14 days before you apply**.
Opting out and back in restarts that tester's 14 days.

- You need **12 opted-in testers**; you have **0 opted in** and **5 configured**. Even if all 5 join you need **≥ 7 more**;
  counting only distinct real people (not your own or the review account), **≥ 9 more**. Recruit 15–20 for margin.
- The 14 days can only start once the closed test is **published** (after Google's review of the first release).
- **Earliest application** = the day the 12th tester has been opted in for 14 consecutive days. Example: test live and 12 testers in
  on 1 Nov 2026 → apply on 15 Nov 2026 → Google says review "usually takes seven days or less". Approval is not guaranteed;
  Google also judges tester engagement.
- The application asks about recruitment, engagement and feedback (three 300-character answers), the app's audience and value,
  expected first-year installs, changes made from testing and how you judged production readiness.

## 8. Questions for you — WAITING FOR MY INPUT

1. **Rights:** do you hold written licences or permission for every recording and image you ship? If not, which songs should come out?
2. **Advertising ID:** keep Firebase's advertising-ID collection (declare *Yes → Analytics*) or remove `AD_ID` and the two
   `ACCESS_ADSERVICES_*` permissions and turn off ad-ID collection (declare *No*)? I recommend removing it: no ads, teen audience,
   one less disclosure. Removing it means rebuilding (still code 3) and updating the privacy policy.
3. **Data safety:** approve the four corrections above?
4. **Content rating:** do any songs contain references to alcohol, drugs or tobacco, profanity, sexual or violent content?
   ("Pen De Daru" suggests yes.) The answers decide whether the 3+/Everyone rating still holds.
5. **Foreground service video:** record 20–30 seconds on a phone: play a song, leave the app, show playback continuing with the
   notification and lock-screen controls. Upload it unlisted on YouTube (or a Drive link anyone can view) and send me the link.
6. **App access:** switch the reviewer instructions to "Tap *Continue as Guest* — all features work; Google sign-in only syncs favourites",
   or keep the review Google account? (Reviewers often cannot pass Google's new-device checks on a personal Gmail.)
7. **Testers:** which of the 5 addresses are distinct real people? Will you add more, and should any other countries be targeted?
8. **Build:** ship the 1.0.2 (3) snapshot, or wait for the in-progress player/Home work?
9. **Firebase:** may I add the two app-signing fingerprints in 2.2 (or will you)?

## 9. Your next step

1. Answer **Q1 (rights)**. Nothing should go to testers until this is settled.
2. Add the app-signing fingerprints in Firebase (2.2), or reply "approve" and I'll do it in the browser.
3. Answer Q2–Q8 and send the video link (Q5).
4. Optional: set up API access (`scripts/release/README.md`) if you want command-line uploads.

## 10. What the agent does next (after your answers)

1. Build the final bundle with `scripts/release/release_android.sh --min-version-code 2` (or the API check) — rebuilding without
   `AD_ID` if you choose that — and confirm package, version code and upload-key signature again.
2. In Play Console (browser): replace the stale draft "2 (1.0.1)" on Closed testing – Alpha with the new bundle and release notes,
   **save as draft**, run *Preview and confirm* and report any errors.
3. Fill the Advertising ID, Foreground service and corrected Data safety declarations, the content-rating questionnaire and the
   app-access instructions — showing you each set of answers before saving.
4. With your explicit approval only: **Send for review** the closed test. Never production.
5. Once live: record the opt-in link, track opted-in testers and the 14-day window, and draft the production-access answers for your review.
6. If API access exists: verify with `play_publish.mjs status` and use it for later uploads.
