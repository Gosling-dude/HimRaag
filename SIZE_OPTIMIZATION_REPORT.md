# App Size Optimization (Phase 16)

**Date:** 2026-08-03

## Measured result

| Artifact | Before | After | Change |
|---|---:|---:|---:|
| Release AAB | 65,665,387 B (62.6 MB) | **65,031,873 B (62.0 MB)** | **−633 KB** |

The AAB reduction is **net** of two opposing changes: −1.6 MB from unbundling the
icon, plus ~1 MB added by the `flutter_localizations` locale data required to fix
the Hindi-locale crash (see CRASH_REPORT.md). That trade — correctness over bytes —
was made deliberately.

## ⚠️ The 62 MB figure is not what users download

An AAB is a **publishing format** containing native libraries for *every* ABI
(`arm64-v8a`, `armeabi-v7a`, `x86_64`) plus all density and language resources.
Google Play generates per-device split APKs from it, so **a typical device
downloads roughly 20–25 MB, not 62 MB.**

Play Console shows the real per-device size after upload — check "App bundle
explorer → Download size" there rather than judging by the AAB.

To see the split locally:
```bash
flutter build apk --release --split-per-abi
# produces app-arm64-v8a-release.apk — the realistic single-device size
```

## Changes made

### 1. Unbundled `assets/icons/` — **−1.6 MB**

`app_icon.png` (1,614,197 B) was shipped inside every install but **never loaded at
runtime**. It exists only as the build-time source for `flutter_launcher_icons`,
which reads it from disk and generates mipmap resources.

Verified unreferenced by grepping `lib/`, `web/`, `test/` and `integration_test/`
for `assets/icons` — no matches. The web build uses `web/icons/`, a different path.
The file remains on disk, so `dart run flutter_launcher_icons` still works.

### 2. Removed empty asset declarations

`assets/animations/` and `assets/fonts/` each contained only a `.gitkeep`.
Declaring them bundled the placeholder and nothing else.

## Asset inventory (post-change)

| Asset | Size | Bundled | Justification |
|---|---:|---|---|
| `assets/images/opening_page.png` | 2.12 MB | ✅ | Splash image, loaded at `bootstrap_app.dart:102` |
| `assets/catalog/imported_catalog.json` | 1.11 MB | ✅ | **Keep** — 697-song offline fallback; the entire no-network first-launch experience |
| `assets/icons/app_icon.png` | 1.61 MB | ❌ | Build-time only |
| `assets/animations/`, `assets/fonts/` | 0 B | ❌ | Empty |
| **Total bundled** | **≈3.2 MB** | | down from ≈4.8 MB |

## Already optimal — no action needed

| Mechanism | Status |
|---|---|
| R8 / ProGuard minification | ✅ `minifyEnabled true` |
| Resource shrinking | ✅ `shrinkResources true` |
| Icon tree-shaking | ✅ **MaterialIcons 1,645,184 B → 10,960 B (99.3% reduction)**, automatic |
| Audio not bundled | ✅ All 956 tracks stream from R2 — this previously saved ~67 MB |
| Admin dashboard | ✅ Unreachable from the consumer router, so tree-shaken out |

## Remaining opportunities (not applied)

### 1. `opening_page.png` — 2.12 MB for one splash image (P2)

The largest remaining bundled asset. Converting to WebP typically saves 60–80 % at
visually identical quality:

```bash
cwebp -q 85 assets/images/opening_page.png -o assets/images/opening_page.webp
```

**Not done** because it alters a rendered image and the brief forbids UI changes.
Likely saves ~1.5 MB if you want it — verify the splash still looks right.

### 2. Drop `firebase_analytics` (P3)

Zero `logEvent` calls. Removing it would cut the SDK and its transitive Play
Services dependency, *and* remove the approximate-location and advertising-ID rows
from your Data Safety form.

**Not done** — the SDK auto-collects, so it is a functioning feature, and removing
working features is out of scope. Purely your product call.

### 3. Bundle fonts (increases size, improves UX)

`google_fonts` fetches at runtime. Bundling would *add* size but remove a network
dependency and fix off-brand text on an offline first launch. See UX_REPORT.md.
