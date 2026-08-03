# HimRaag — R2 Cache-Header Report

_Generated: 2026-08-03T18:59:51.349Z_

**Bucket:** `himraag-audio` · **Public base:** `https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev`

**Policy applied to every object:**

```
Cache-Control: public, max-age=31536000, immutable
```

---

## 1. Migration summary

| Metric | Value |
|---|---|
| Mode | `commit` |
| Total objects enumerated | **4238** |
| Objects updated | **4238** |
| Objects skipped (already correct) | 0 |
| Failures | 0 |
| Elapsed time | 168.5s |

### By prefix

| Prefix | Total | Updated | Skipped | Failed |
|---|---:|---:|---:|---:|
| `albums/` | 149 | 149 | 0 | 0 |
| `artist/` | 12 | 12 | 0 | 0 |
| `artists/` | 206 | 206 | 0 | 0 |
| `artwork/` | 2914 | 2914 | 0 | 0 |
| `audio/` | 957 | 957 | 0 | 0 |

**No failures.**

---

## 2. Verification

Each sampled object is checked twice: an authenticated S3 `HeadObject` (authoritative — proves the header is stored on the object) and a public `HEAD` on the r2.dev URL with a cache-busting query string (proves a real client sees it). `cf-cache-status` is shown because Cloudflare's edge may still hold a pre-migration entry for a hot URL — that is edge staleness, not a migration failure.

| Check | Result |
|---|---|
| Objects sampled | 80 |
| Correct `Cache-Control` at origin (S3 HEAD) | **80 / 80** |
| HTTP 200 OK on public URL | **80 / 80** |
| Correct `Cache-Control` over public HTTP | **80 / 80** |

### Full-bucket census (all 4,238 objects, not a sample)

A sample can't prove the migration left no stragglers or altered a Content-Type,
so every object was re-`HeadObject`-ed after the migration:

| Check | Result |
|---|---|
| Objects carrying the correct `Cache-Control` | **4238 / 4238** |
| Objects with a `Content-Type` mismatching their file extension | **0** |
| Objects downgraded to `application/octet-stream` | **0** |

Content-Type distribution across the whole bucket — `audio/mpeg` still accounts
for exactly the 957 objects under `audio/`, so no audio object's type was
altered:

| Content-Type | Objects |
|---|---:|
| `image/jpeg` | 1892 |
| `image/png` | 1382 |
| `audio/mpeg` | 957 |
| `image/webp` | 7 |

### MP3 audio — 20 sampled of 957 (`audio/`)

| # | URL | Content-Type | Cache-Control | HTTP | cf-cache |
|---|---|---|---|---|---|
| 1 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/maa-kalratri-ki-aarti-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 2 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/haaye-radhika-remix-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 3 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/mesang-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 4 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/mero-himwanti-desa-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 5 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/holi-ko-tyohar-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 6 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/oh-diye-kauliye-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 7 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/baand-bijora-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 8 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/ramo-ri-raniye-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 9 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/ghadyalu-tamasu-saas-bahu-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 10 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/chechonu-rajang-2-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 11 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/anushka-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 12 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/laali-ho-govind-digari-khushi-joshi-chandani-enterprises-kumaoni-song-kishan-mah.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 13 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/pahadon-ko-raibasi-256k.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 14 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/ho-shushma-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 15 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/potga-badang-padige-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 16 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/tumi-bola-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 17 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/jaagar-bali-vasudanta-arjun-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 18 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/ranikheta-ramdhola-kishan-mahipal-uttarakhandi-garhwali-song-himalayanfilms-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 19 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/shambhu-hindi-shiv-bhajan-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 20 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/mama-kirtiram-0.mp3 | `audio/mpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |

### Song artwork — 20 sampled of 2914 (`artwork/`)

| # | URL | Content-Type | Cache-Control | HTTP | cf-cache |
|---|---|---|---|---|---|
| 1 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/rana-sate-singh-ena-laika-v4.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 2 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/hey-jamana-0.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 3 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/baheen-bin-tarsaeebo-tora-v4.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 4 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/komniya-thanedara-by-mohan-singh-chauhan-paharisong-0.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 5 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/nati-theogiya-shayam-singta-latest-himachali-pahari-song-2024-anvirecords-0.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 6 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/lehenga-5-0.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 7 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/dhire-dhire-o-chanda-v4.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 8 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/raniban.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 9 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/kerte-hai-sanam-0-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 10 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/bo-chaantha-ucha-ucha-chaantha-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 11 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/dj-natti-best-of-mohan-singh-chauhan-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 12 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/farmaish-latestphadi-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 13 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/gujariye-v4.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 14 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/thando-re-thando-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 15 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/kurti-teri-laal-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 16 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/dupatta-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 17 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/baheen-bin-tarsaeebo-tora-0.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 18 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/shiv-vivah-v4.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 19 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/gaini-padi-bal-ghero-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 20 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/latest-himachali-jaunsari-songs-2021-v4-t400.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |

### Artist photos — 20 sampled of 218 (`artist/`, `artists/`)

| # | URL | Content-Type | Cache-Control | HTTP | cf-cache |
|---|---|---|---|---|---|
| 1 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artist/anuradha-paudwal-v5.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 2 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artist/maya-upadhyay-v5.jpg | `image/jpeg` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 3 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/babli.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 4 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/gopi-da-pahadi-manju-nautiyal.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 5 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/mamta-arya.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 6 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/narendra-singh-negi-anuradha-nirala.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 7 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/satish-bushahri-babli-negi.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 8 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/pankaj-raj-manju-nautiyal.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 9 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/gyanu-mala-bhimma-kathait.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 10 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/preetam-bhartwan-meena-rana-sangeeta-dhoundiyal.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 11 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/anurag-kant-manju-nautiyal.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 12 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/palak-hardik-v3.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 13 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/narendra-singh-negi-anuradha-nirala-mangla-rawat-usha-negi.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 14 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/narindra-singh-negi-pritam-bharathwan-manglesh-dangwal.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 15 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/pankaj-raaj.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 16 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/manju-nautiyal-reshma-bhatt.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 17 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/gajender-rana.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 18 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/manju-nautiyal-kavita-panwar.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 19 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/dominic-glynn.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 20 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artists/gajendra-rana.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |

### Album artwork — 20 sampled of 149 (`albums/`)

| # | URL | Content-Type | Cache-Control | HTTP | cf-cache |
|---|---|---|---|---|---|
| 1 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/dhyani-anuven-latest-jaunsari-himachali-audio-song-singer-attar-shah-lyrics-deve.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 2 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/nati-mehfil-2023.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 3 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/wah-bhai-ji.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 4 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/diksha-dhaundiyal-pooja-dhaundiyal-singles-v2.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 5 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/garhwali-bhakti-sangeet.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 6 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/negi-ki-cheli-title-song.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 7 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/gange-rama-drivra-by-mohan-singh-chauhan.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 8 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/garhwali-bhakti-sangeet-v2.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 9 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/sardar-singh-sharma-singles-v3.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 10 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/binniye.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 11 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/mohan-singh-chauhan.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 12 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/sardar-singh-sharma-singles-v2.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 13 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/dhire-dhire-o-chanda.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 14 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/nati-geetmala.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 15 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/thandande-ganiyat-latest-jaunsari-uttrakhandi-song-by-attar-shah-meena-rana.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 16 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/nazar-na-lago.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 17 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/jaipuriya-saree.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 18 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/pahadi-jhankar.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 19 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/diksha-dhaundiyal-pooja-dhaundiyal-singles.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |
| 20 | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/albums/zorawar-hunk-singles-v3.png | `image/png` | ✅ `public, max-age=31536000, immutable` | ✅ 200 OK | — |

---

## 3. Permanence — future uploads

Every R2 write in this repo goes through `scripts/lib/r2_client.js`, whose `putObject()` sets the policy on every `PutObject` and ignores any caller-supplied `CacheControl`. Call sites routed through the helper:

| Script | Uploads |
|---|---|
| `scripts/r2_upload.js` | audio + artwork + artist/album covers |
| `scripts/fetch_real_art.js` | real song/artist/album cover art |
| `scripts/fetch_artist_images.js` | artist photographs |
| `scripts/generate_thumbnails.js` | `-t400.jpg` thumbnails |
| `scripts/regenerate_art.js` | generated covers (deprecated path) |
| `scripts/repair_artist_images.js` | list-only — no uploads (client unified anyway) |

A new upload script inherits the policy simply by using the helper; the raw `PutObjectCommand` no longer appears anywhere else in the repo.

## 4. Operational notes

- **`immutable` requires stable keys.** Image keys are content-versioned (`-v5`, `-t400`), so a re-render produces a new key and clients pick it up. **Audio keys (`audio/<slug>.mp3`) are not versioned** — with `max-age=31536000, immutable`, replacing an MP3 in place will not reach clients that already cached it. Publish replacement audio under a new key (e.g. `-v2`) instead of overwriting.
- **R2 has no per-object ACLs.** Public access comes from the bucket's `pub-*.r2.dev` binding, so no ACL is preserved or sent — nothing to migrate.
- **Object bytes were never touched.** The migration is a server-side self-copy with `MetadataDirective: REPLACE`, re-supplying Content-Type, user metadata, Content-Disposition/Encoding/Language. Verified on a throwaway object: ETag, size, content type, user metadata and disposition all identical before/after.
- **The migration is idempotent.** Objects already carrying the policy are reported as `skipped`; re-running is safe.
- **Scope.** No Flutter, Firestore, or UI code is involved — neither script imports `firebase-admin`.
