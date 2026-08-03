# HimRaag — Final Production Readiness Deliverables (Phase 20)

**Date:** 2026-08-03 · **Audit type:** Release Candidate, 20-phase

> Supersedes the 2026-07-04 stabilization summary of the same name (preserved in
> git history at commit `3c8bf09`).

---

## 🔑 The one thing to read first

**Your APK, for re-verification:**

```
D:\Personal Projects\HimRaag\build\app\outputs\flutter-apk\app-release.apk
```

```bash
adb install -r "D:\Personal Projects\HimRaag\build\app\outputs\flutter-apk\app-release.apk"
```

This build **targets API 36 instead of 35**, so please re-check the items in
"What to verify" below — especially edge-to-edge layout, which is new behaviour
your earlier testing could not have covered.

---

## Build artifacts

| Item | Value |
|---|---|
| **Release APK** | `build/app/outputs/flutter-apk/app-release.apk` |
| **APK size** | 64,415,455 B — **61.4 MB** |
| **Release AAB** (upload this to Play) | `build/app/outputs/bundle/release/app-release.aab` |
| **AAB size** | 65,031,873 B — **62.0 MB** |
| **ProGuard mapping** | `build/app/outputs/mapping/release/mapping.txt` (33.4 MB) |
| Per-device download | **~20–25 MB** — Play splits the AAB by ABI; 62 MB is the multi-ABI publishing format |

## Environment

| Item | Value |
|---|---|
| Commit hash | `54d0b155732fbe7794438c017d6312d10460a9f0` |
| Branch | `feat/import-new-pahadi-songs` |
| **Git status** | ⚠️ **NOT clean** — 6 modified, 19 new reports uncommitted (deliberate; see below) |
| Flutter | 3.44.4 stable · Dart 3.12.2 |
| Firebase project | `himraag-prod` |
| versionName / versionCode | 1.0.0 / 1 |
| compileSdk / targetSdk / minSdk | 36 / 36 / 24 |

> Changes are left uncommitted on purpose — committing was not requested, and you
> should review the API 36 upgrade on a device first. To commit:
> `git add -A && git commit -m "chore: production readiness audit"`

## Catalogue (live Firestore)

| Metric | Count |
|---|---:|
| **Total songs** | **956** |
| **Total artists** | **217** |
| **Total albums** | **173** |
| Categories | 6 |
| **Total playlists** | **0** (feature built, unused) |
| Users | 19 |
| Audit logs | 4 |
| Regions / submissions / featured / banners | 0 each |
| **Total Firestore documents** | **1,375** |
| Bundled offline catalogue | 697 songs / 102 albums / 148 artists — a **strict subset** of Firestore (0 missing) |

## Cloudflare R2

| Metric | Value |
|---|---:|
| **Total objects verified** | **2,302** |
| Reachable | **2,299 (99.87 %)** |
| Audio files | **956/956 — 100 %** |
| Album artwork | 173/173 — 100 % |
| Song artwork | 954/956 |
| Artist images | 216/217 |
| **Broken URLs** | **3** (1 transient timeout, 2 missing URLs — all cosmetic; branded fallback renders) |
| **Duplicates removed** | **0** — none found; 0 duplicate audio URLs in sample |
| **Missing metadata** | **2** (`Mahima Ke Varnan` artwork, `Pankaj Raaj` image) |

## Quality gates

| Gate | Result |
|---|---|
| `flutter analyze` | ✅ **No issues found** |
| `flutter test` | ✅ **16/16 passed** (12 existing + 4 new) |
| `flutter build apk --release` | ✅ Succeeded |
| `flutter build appbundle --release` | ✅ Succeeded |
| **Signing verified** | ✅ **AAB and APK fingerprints identical to the upload keystore** |

---

## Issues found and fixed

| # | Sev | Issue | Fix |
|---|---|---|---|
| 1 | **P0** | **Release build failed to compile** — stale `GeneratedPluginRegistrant.java` registered the `integration_test` dev plugin | `flutter clean` before release builds (documented) |
| 2 | **P0** | **`targetSdk 35`** — Play requires **API 36 from 2026-08-31**, 28 days away | Raised compileSdk/targetSdk to 36 |
| 3 | **P0** | Missing keystore **silently debug-signed** releases | Release now fails loudly; debug unaffected |
| 4 | **P1** | **Hindi-locale crash** — `hi` declared supported with no localization delegates; any dialog/tooltip would throw | Added the three `Global*Localizations` delegates |
| 5 | **P1** | Search issued **a Firestore query per keystroke** (18 reads to type "pahadi") | 300 ms debounce + 4 tests → **6× fewer reads** |
| 6 | P2 | Two unused permissions (`READ_EXTERNAL_STORAGE`, `RECEIVE_BOOT_COMPLETED`) | Removed after proving them unreferenced |
| 7 | P2 | 1.6 MB icon bundled but never loaded at runtime | Unbundled |

## Verification status — honest accounting

| Capability | Status |
|---|---|
| **Google Sign-In** | ⚠️ **Partly verified.** The APK's signing SHA-1 (`c0eb64dd…93405`) **is registered** in `google-services.json`, so sign-in will work for this APK. **See the Play App Signing warning below.** |
| **Background playback** | ❌ NOT VERIFIED — code path is sound and defensively written; needs a device |
| **Notification playback** | ❌ NOT VERIFIED — manifest declarations correct |
| **Lock-screen controls** | ❌ NOT VERIFIED |
| **Offline playback** | ❌ NOT VERIFIED — downloads are app-private, catalogue is bundled |
| **Startup time** | ❌ **NOT MEASURED** — no device. Commands in PERFORMANCE_REPORT.md |
| **Memory usage** | ❌ **NOT MEASURED** — no device |
| Streaming reachability | ✅ VERIFIED — 956/956 audio URLs return 200/206 |
| Seek support | ✅ VERIFIED — R2 returns `Accept-Ranges: bytes` |
| Artwork coverage | ✅ VERIFIED — 1,343/1,346 |

**No performance or playback number in these reports is estimated.** Where a
device was required and unavailable, it says so.

---

## ⚠️ Three things that can still bite you

### 1. Play App Signing will break Google Sign-In unless you add a second SHA-1

When you upload the AAB, **Google re-signs it with a different key**. Your users
get an app signed by Google's key, *not* by `himraag-upload`. Firebase only knows
about the upload key's SHA-1.

**Result: Google Sign-In works perfectly in this APK and fails for every Play
user** — the single most common production sign-in failure, and consistent with
the sign-in trouble already seen on this project.

**Fix, after your first upload:**
1. Play Console → Release → Setup → **App signing**
2. Copy the **SHA-1 of the "App signing key certificate"** (not the upload key)
3. Firebase Console → Project settings → Your Android app → **Add fingerprint**
4. Download the refreshed `google-services.json` and rebuild

### 2. R2 objects have no `Cache-Control` header

Not one of the 2,302 objects sets it. Cloudflare's edge cannot cache confidently,
so traffic hits the origin — which is exactly why `pub-*.r2.dev` returns HTTP 429
under load, the problem the app already works around client-side.

The content is immutable (new track → new key), so `public, max-age=31536000,
immutable` is safe. **Do this before any marketing push** — it is the highest-value
remaining change and needs no app update. Details in R2_AUDIT.md.

### 3. Privacy policy must be hosted before you can publish

`legal/PRIVACY_POLICY.md` and `legal/TERMS_AND_CONDITIONS.md` are written against
the app's real data flows. You must replace `[INSERT CONTACT EMAIL]` in both, host
them publicly, and enter the URL in Play Console. Also declare **approximate
location and device IDs** on the Data Safety form — `firebase_analytics`
auto-collects these despite zero `logEvent` calls.

---

## What to verify on the new APK

Because targetSdk moved 35 → 36, your earlier testing does not fully carry over.

**New behaviour introduced by API 36:**
- [ ] **Edge-to-edge is enforced** — confirm the bottom nav and mini player are not hidden behind the system nav bar
- [ ] **Portrait lock is ignored on ≥600dp screens** — check landscape if you support tablets/foldables

**Fixed this pass — please confirm:**
- [ ] **Set the device language to हिन्दी**, open the app, trigger a dialog or long-press a text field — must not crash
- [ ] Search feels responsive and no longer flickers mid-typing

**Regression pass:**
- [ ] Google Sign-In · [ ] Background playback · [ ] Notification controls ·
      [ ] Lock-screen controls · [ ] Bluetooth buttons · [ ] Download and play offline ·
      [ ] Artwork loads across Home

> **Fallback:** if edge-to-edge causes layout problems, API 35 remains valid for
> submissions **before 31 Aug 2026**. Reverting `targetSdk` to 35 in
> `android/app/build.gradle` is a one-line change. Your call.

---

## Play Store compliance summary

| Requirement | Status |
|---|---|
| Target API 36 | ✅ Met |
| App Bundle format | ✅ AAB produced |
| Release signing | ✅ Verified against keystore |
| Foreground service type declared | ✅ `mediaPlayback` |
| Notification permission | ✅ `POST_NOTIFICATIONS` |
| No unused permissions | ✅ Two removed |
| Cleartext traffic blocked | ✅ |
| Privacy policy | ⚠️ Written, **must be hosted** |
| Data Safety form | ⚠️ Rows specified in PLAYSTORE_COMPLIANCE_REPORT.md |
| Account deletion route | ⚠️ Email route documented; a web form is safer |
| Content rating | ⚠️ IARC questionnaire outstanding |
| **Music licensing** | ⚠️ **Your biggest non-technical risk** — 956 tracks; be ready to evidence rights |

**No known technical blocker to upload.** Remaining items are console paperwork
and the licensing question, which is a business matter rather than an engineering one.

---

## Reports produced

Phases 1–20: `PROJECT_AUDIT` · `CODE_QUALITY_REPORT` · `PERFORMANCE_REPORT` ·
`FIRESTORE_AUDIT` · `R2_AUDIT` · `SECURITY_REPORT` · `PLAYSTORE_COMPLIANCE_REPORT` ·
`UX_REPORT` · `PLAYBACK_REPORT` · `IMAGE_REPORT` · `SEARCH_REPORT` ·
`PERSONALIZATION_AUDIT` · `OFFLINE_REPORT` · `CRASH_REPORT` · `RELEASE_REPORT` ·
`SIZE_OPTIMIZATION_REPORT` · `STORE_LISTING` · `legal/PRIVACY_POLICY` ·
`legal/TERMS_AND_CONDITIONS` · `legal/COOKIE_POLICY`

> **Housekeeping note:** the repo root now holds ~65 markdown reports, most from
> earlier sessions. I left the pre-existing ones untouched **with one exception**:
> `UI_VERIFICATION_REPORT.md` was regenerated by `scripts/verify_all_urls.js` when I
> ran the R2 sweep, so it now carries today's 2,302-URL results instead of the
> previous 389-byte stub. That is an improvement, but it is a change — revert with
> `git checkout UI_VERIFICATION_REPORT.md` if you would rather keep the old one.
> Consider moving historical reports into `docs/archive/` — but that is churn you
> did not ask for, so it is your call.

---

## ⚠️ Rebuilding: run `flutter clean` first

The artifacts above were built from a clean tree (AAB 19:35, APK 19:39, after the
clean rebuild began at 19:34) and are **valid**. But the final `flutter analyze` +
`flutter test` pass I ran afterwards regenerated `GeneratedPluginRegistrant.java`
with the `integration_test` plugin in it — so **the repo is currently in the state
that fails a release build.**

If you rebuild yourself:
```bash
flutter clean && flutter build apk --release
```

`scripts/build_release.ps1` now starts with `flutter clean` so this cannot recur
through that path.
