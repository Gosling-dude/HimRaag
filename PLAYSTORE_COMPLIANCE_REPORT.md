# Google Play Compliance Report (Phase 7)

**Date:** 2026-08-03 · **Package:** `com.himraag.app`

## ⛔ Rejection risks — read first

### 1. Target API level (was a hard blocker — fixed)

Verified against the live requirements page today, not from memory:

> **From 31 August 2026, new apps and app updates must target Android 16 (API 36).**
> Existing apps must target API 35+ to stay available to new users.
> Extensions to 1 November 2026 can be requested.

The app targeted **API 35**. Any submission on or after **31 Aug 2026 — 28 days
from now — would have been rejected.** Raised `compileSdk` and `targetSdk` to 36.

> ⚠️ **This invalidates your device testing.** You smoke-tested an API 35 build.
> API 36 **enforces edge-to-edge** (the opt-out is ignored) and **ignores
> `screenOrientation="portrait"` on screens ≥600dp wide** (tablets/foldables).
> `MiniPlayerOverlay` and the bottom nav both use `SafeArea`, and Flutter 3.44
> handles edge-to-edge natively, so this should be fine — **but please re-check
> the bottom nav and mini player for overlap with the system nav bar** on the new
> APK.
>
> **Fallback if you hit problems:** API 35 remains valid for anything submitted
> **before 31 Aug 2026**. Reverting `targetSdk` to 35 is a one-line change and
> buys time. Your call.

### 2. Privacy policy URL — action required

Play **requires a publicly hosted privacy policy URL** for any app that collects
personal data. This app collects account and usage data, so it is mandatory.

`legal/PRIVACY_POLICY.md` and `legal/TERMS_AND_CONDITIONS.md` are written and
ready. **You must:**
1. Replace `[INSERT CONTACT EMAIL]` in both files.
2. Host them at a public URL (GitHub Pages works).
3. Enter the privacy-policy URL in Play Console → App content.

Missing or unreachable policy URLs are among the most common rejection causes.

---

## Data Safety form — declare exactly this

Derived from the actual code paths, not guessed.

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Name | Yes | No | Only if you sign in | Account |
| Email address | Yes | No | Only if you sign in | Account |
| User IDs | Yes | No | Only if you sign in | Account |
| Photos (profile URL) | Yes | No | Only if you sign in | Account |
| App interactions | Yes | No | No | Analytics |
| Crash logs | Yes | No | No | Diagnostics |
| Diagnostics | Yes | No | No | Diagnostics |
| Device/other IDs | Yes | No | No | Analytics |
| **Approximate location** | **Yes** | No | No | Analytics *(IP-derived, by Firebase Analytics)* |
| Music/audio files | No | No | — | Downloads never leave the device |
| Precise location, contacts, SMS, calls, health, financial | **No** | — | — | Not requested |

**Also declare:** data is encrypted in transit ✅; users can request deletion ✅
(state the method — the policy gives an email route).

> ⚠️ **Do not skip the approximate-location and device-ID rows.** `firebase_analytics`
> is a dependency and **auto-collects even though the app makes zero `logEvent`
> calls** — screen views, session data, device model, IP-derived coarse location
> and an advertising ID. Under-declaring this is a policy violation. The SDK was
> deliberately kept (it is genuinely functioning), so it must be declared.

## Permissions declared

| Permission | Justified |
|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | ✅ streaming |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | ✅ background audio |
| `WAKE_LOCK` | ✅ uninterrupted playback |
| `POST_NOTIFICATIONS` | ✅ playback notification |

**Removed this pass:** `READ_EXTERNAL_STORAGE` and `RECEIVE_BOOT_COMPLETED` — both
unused. Neither now needs a Data Safety justification.

### Foreground service type — compliant

`mediaPlayback` is declared both in the manifest `<service>` element and via
`FOREGROUND_SERVICE_MEDIA_PLAYBACK`. Since API 34, Play requires a declared FGS
type and an in-console justification. **You will be asked to explain foreground
service use in Play Console** — the answer is: *continuing music playback while the
app is backgrounded, surfaced through a media notification with transport controls.*
Play accepts this readily for a music player.

## Other policy areas

| Area | Status |
|---|---|
| Account deletion | ⚠️ Play requires an **in-app** route *or* a web URL for account+data deletion. The policy gives an email route — acceptable, but a web deletion form is safer. **Verify you have entered a deletion URL in Play Console.** |
| Ads | ✅ None. Declare "No ads". |
| In-app purchases | ✅ None. |
| Content rating | Complete the IARC questionnaire. Expect **Everyone / PEGI 3** — folk music, no UGC-visible-to-others, no chat. |
| Target audience | Declare **13+**. The app is not designed for children, which keeps it out of Families policy and its stricter analytics rules. |
| App category | **Music & Audio** |
| Third-party licences | ⚠️ See below |
| **Copyright-sensitive content** | ⚠️ **See below — this is your real risk** |

### ⚠️ Music licensing — the biggest non-technical risk

The app streams **956 music tracks**. Play's Intellectual Property policy will
suspend apps distributing music without rights. Technical readiness does not help
here. Before publishing, be sure you can evidence:

1. Rights or licences for every track, or documented public-domain/traditional status.
2. Artist permission for the 217 artist images and 173 album covers.
3. A takedown route — §5 of the Terms provides one; make sure the address works.

The catalogue is flagged `LICENSED` internally (`test/local_catalog_test.dart`
asserts it), but that is an app-side flag, **not legal proof**. Keep the paperwork
where you can produce it on request.

### Third-party licences

The app bundles Apache-2.0/BSD/MIT libraries (Firebase, just_audio, Riverpod,
go_router, dio, Hive, google_fonts). All permit redistribution. There is currently
**no in-app open-source licences screen** — Play does not require one, but Flutter
provides `showLicensePage()` if you want it. Not a blocker.

> **Note on `google_fonts`:** it fetches fonts over the network at runtime and
> caches them. `assets/fonts/` is empty, so fonts are not bundled. On a cold
> offline first launch, text falls back to the system font. Cosmetic only — but if
> you want deterministic typography, bundle the font files.

## Verdict

**No known technical blocker to upload**, provided you:

1. host the privacy policy and enter the URL,
2. fill the Data Safety form as tabled above (including approximate location),
3. confirm the music rights position,
4. re-check the API 36 build on your device for edge-to-edge layout.
