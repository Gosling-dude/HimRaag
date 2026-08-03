# Play Store Listing Assets (Phase 18)

**App:** HimRaag — Pahadi Music, Heart of the Hills · **Package:** `com.himraag.app`

---

## App category

**Primary:** Music & Audio
**Tags:** Music streaming · Folk music · Regional music
**Content rating:** Everyone (complete the IARC questionnaire — expect Everyone / PEGI 3)
**Target audience:** 13+

---

## Short description (max 80 characters)

> Pahadi folk music streaming — Himachali songs, artists and albums in one app.

*(78 characters)*

**Alternatives:**
- `Stream Pahadi & Himachali folk music. 950+ songs, offline downloads.` (68)
- `Heart of the Hills — Pahadi folk music streaming, free and offline.` (66)

---

## Full description (max 4000 characters)

```
HimRaag brings the music of the Himalayas to your phone.

Stream over 950 Pahadi and Himachali folk songs — traditional melodies,
devotional music and regional favourites from across Himachal Pradesh and the
wider hill country. Discover artists you grew up hearing and albums you have not
heard in years, all in one place.

WHAT YOU CAN DO

• Stream 950+ Pahadi songs from more than 200 artists
• Browse by region, category and album
• Search across songs, artists and albums instantly
• Download tracks and listen offline, anywhere
• Keep listening in the background while you use other apps
• Control playback from your notification shade and lock screen
• Save favourites and build your own playlists
• Pick up exactly where you left off with Continue Listening

BUILT FOR THE HILLS

Choose the regions and styles you care about, and HimRaag shapes your home
screen around them. Sign in to carry your favourites and history across devices —
or use it as a guest, with everything kept on your phone.

LISTEN OFFLINE

Download any track and play it with no signal at all. Perfect for travel through
the hills, where the network is not.

FOLK MUSIC, PROPERLY PRESENTED

Every song carries proper artist, album and region information, with artwork
throughout. No clutter, no interruptions.

HimRaag is free to use, with no ads and no subscriptions.

Heart of the Hills.
```

*(~1,250 characters — well inside the limit, with room to add a section.)*

---

## Keywords / ASO terms

Play has no keyword field; these should appear naturally in the title and
description (they already do above):

**Primary:** pahadi music · himachali songs · pahadi songs · himachal music · folk music
**Secondary:** garhwali · kumaoni · uttarakhand music · hill music · devotional pahadi ·
pahadi geet · himalayan music · regional indian music · offline music
**Long-tail:** pahadi songs download · himachali folk songs · pahadi music app

---

## Release notes (v1.0.0)

```
Welcome to HimRaag — Pahadi music, heart of the hills.

• Stream 950+ Pahadi and Himachali folk songs
• Download and listen offline
• Background playback with lock-screen controls
• Search songs, artists and albums
• Personalised home feed by region and style
• Save favourites and continue where you left off
```

**Template for later releases** — be specific, users read these:
```
• Faster search
• Fixed artwork not loading on some devices
• Improved playback stability in the background
```

---

## Promotional text (max 170 characters)

> Over 950 Pahadi and Himachali folk songs, free and offline. Discover the artists of the hills — and take them with you wherever you go.

*(136 characters)*

---

## Feature graphic (1024 × 500 px, required)

Play crops and scales this aggressively; keep it simple.

**Recommendation:**
- Himalayan ridgeline silhouette against the brand purple (`#6B3FA0`) on the deep
  base (`#0D0D14`) — consistent with the existing app icon and splash.
- "HimRaag" wordmark **left-third**, with the tagline *Heart of the Hills* beneath.
- Keep all text within the **centre 80 %** — edges get cropped on some layouts.
- **No screenshots or device frames inside the feature graphic** — Play policy.
- Legible at 320 px wide, which is where most users actually see it.

## App icon (512 × 512 px, 32-bit PNG)

Already available: `assets/icons/app_icon.png`. Confirm no alpha channel and no
rounded corners baked in — Play applies its own mask.

---

## Screenshots (min 2, max 8 — supply 6)

Phone: 16:9 or 9:16, min 320 px, max 3840 px on the long edge.

| # | Screen | Caption |
|---|---|---|
| 1 | Home | **950+ Pahadi songs, curated for you** |
| 2 | Full player | **Beautiful player with lock-screen controls** |
| 3 | Search | **Find any song, artist or album instantly** |
| 4 | Downloads / Library | **Download once. Listen anywhere, offline.** |
| 5 | Artist detail | **Discover the artists of the hills** |
| 6 | Categories / regions | **Browse by region and style** |

**Tips:** capture in **dark mode** (it suits the palette), use real catalogue
content rather than placeholders, and keep caption text large — screenshots are
viewed at thumbnail size.

```bash
adb exec-out screencap -p > screenshot1.png
```

---

## Contact information checklist

Play requires these before publishing. **All are currently outstanding:**

- [ ] **Support email** — publicly displayed; must be monitored
- [ ] **Privacy policy URL** — mandatory. `legal/PRIVACY_POLICY.md` is written; host it and paste the URL
- [ ] Website (optional)
- [ ] Phone (optional)
- [ ] **Replace `[INSERT CONTACT EMAIL]`** in `legal/PRIVACY_POLICY.md` and `legal/TERMS_AND_CONDITIONS.md`
- [ ] **Account-deletion route** — Play requires an in-app option or a web URL
- [ ] Data Safety form — see PLAYSTORE_COMPLIANCE_REPORT.md for the exact rows
- [ ] Content rating questionnaire
- [ ] Foreground-service justification (answer: background music playback)

---

## Store listing localisation

The app declares `en` and `hi`. Consider a **Hindi** store listing — a large part
of the Pahadi/Himachali audience searches in Hindi, and Play matches listing text
per locale. Translating just the short description and first two screenshot
captions is high-value for the effort.
