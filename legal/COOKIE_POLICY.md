# Cookie Policy — Applicability Note

**Date:** 2026-08-03

## Short answer: not applicable to the Android app

Phase 17 asked for a Cookie Policy "if applicable". **It is not applicable to the
HimRaag Android application**, and publishing one anyway would be misleading.

HimRaag is a native Flutter Android app. It has **no WebView, no embedded browser
and no web content**, so no HTTP cookies are ever set or read on the user's device.
Verified: no `webview_flutter` or equivalent dependency exists in `pubspec.yaml`.

## What the app uses instead

Rather than cookies, HimRaag stores data locally using platform mechanisms. These
are already disclosed in the [Privacy Policy](PRIVACY_POLICY.md):

| Mechanism | Purpose |
|---|---|
| **Hive** (local database) | Preferences, favourites, recently played, download state, cached catalogue |
| **Disk image cache** (`flutter_cache_manager`) | Artwork, 30-day retention |
| **Firestore offline persistence** | Cached documents for offline browsing |
| **Firebase Auth token store** | Keeping you signed in |
| **Firebase Analytics identifiers** | An app-instance ID and an advertising identifier |

The last row is the closest analogue to a tracking cookie, and it is disclosed in
§3.4 of the Privacy Policy and declared as "Device or other IDs" on the Play Data
Safety form.

All of the above is removed when the app is uninstalled.

## When you *will* need a cookie policy

Two cases:

1. **The admin dashboard** (`lib/admin/main_admin.dart`) is a Flutter **web** app.
   If you host it on a public domain, Firebase Auth will set browser storage and a
   cookie notice may be required depending on your jurisdiction. It is an
   internal, credential-gated tool rather than a public site, which usually places
   it outside consumer cookie-consent rules — but confirm this if you expose it
   publicly.

2. **You host the privacy policy and terms on a website.** If that site uses
   analytics or any non-essential cookies, the *site* needs a cookie banner. Plain
   static pages on GitHub Pages with no analytics do not.

**Recommendation:** do not ship a cookie policy with the app. Add one to the
hosting site only if you add analytics to that site.
