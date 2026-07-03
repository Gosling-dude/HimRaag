# ICON UPDATE REPORT

_Generated: 2026-06-24 — branch `feat/import-new-pahadi-songs`_

## Source
- **File:** `assets/icons/app_icon.png`
- **Dimensions:** 1254 × 1254 px (square, no cropping required)
- **Size:** 1.54 MB
- **Design:** Himalayan peaks + folk lute (tungna/sarangi) + music note on dark navy (`#0D0D14`). No text overlay, no AI-poster styling — a clean branded mark.

The previous icon (`app_icon.jpg`, a user photo) was replaced. `pubspec.yaml` `flutter_launcher_icons` config was repointed from `app_icon.jpg` → `app_icon.png` for `image_path`, `adaptive_icon_foreground`, and `web.image_path`.

## Generation
Command: `dart run flutter_launcher_icons` (flutter_launcher_icons 0.13.1) → **Successfully generated launcher icons.**

### Android — all densities generated
| Density | File | Launcher | Round | Adaptive fg |
|---|---|---|---|---|
| mdpi | `mipmap-mdpi/ic_launcher.png` | ✓ | ✓ | `drawable-mdpi/ic_launcher_foreground.png` |
| hdpi | `mipmap-hdpi/ic_launcher.png` | ✓ | ✓ | ✓ |
| xhdpi | `mipmap-xhdpi/ic_launcher.png` | ✓ | ✓ | ✓ |
| xxhdpi | `mipmap-xxhdpi/ic_launcher.png` | ✓ | ✓ | ✓ |
| xxxhdpi | `mipmap-xxxhdpi/ic_launcher.png` | ✓ | ✓ | ✓ |

- **Adaptive icon:** `mipmap-anydpi-v26/ic_launcher.xml` (foreground = icon, background = `#0D0D14` written into `values/colors.xml`). Android 8+ launchers, app-switcher, and themed surfaces use this.
- **Manifest** already references `@mipmap/ic_launcher` / `@mipmap/ic_launcher_round` — no change needed.

### Web / PWA branding
`web/icons/Icon-192.png`, `Icon-512.png`, `Icon-maskable-192.png`, `Icon-maskable-512.png` regenerated; `web/manifest.json` background `#0D0D14`, theme `#6B3FA0`.

## Verification
- ✅ All required Android densities present (mdpi→xxxhdpi) + adaptive + round.
- ✅ Source is 1254² square → not blurry (exceeds 192px xxxhdpi requirement by ~6.5×) and not cropped (1:1 aspect).
- ✅ Adaptive foreground inset on safe-zone background so the launcher mask cannot clip the artwork.
- ⏳ On-device launcher / app-switcher appearance to be confirmed on the release APK (no device attached in this build environment).
