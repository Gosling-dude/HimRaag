# HimRaag — End-to-End Verification (Phase 7)

_Generated: 2026-06-18T09:59:51.147Z_

Traces 5 imported songs through every layer with real evidence — no assumptions. R2 bytes are fetched live; Firestore docs are read back.

## Main Pahadan

| Stage | Evidence |
|---|---|
| 1. Local MP3 (source of truth) | `Main_Pahadan___मैं_पहाड़न___Kumaoni_Song___Diksha_Dhaundiyal___Pooja_Dhaundiyal___Slowed___Reverb(256k).mp3` — exists: **true** |
| 2. Enriched metadata | artist=Diksha Dhaundiyal, Pooja Dhaundiyal · region=Kumaoni/Kumaoni · genre=Folk · conf=0.8 |
| 3. R2 upload (audio) | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/main-pahadan-kumaoni-song-diksha-dhaundiyal-pooja-dhaundiyal-slowed-reverb-256k.mp3 |
| 3a. R2 live fetch | HTTP **206** · type `audio/mpeg` · range `bytes 0-2047/5376812` · 2048B · valid MP3 header: **true** |
| 3b. R2 artwork | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/main-pahadan-kumaoni-song-diksha-dhaundiyal-pooja-dhaundiyal-slowed-reverb-256k.png |
| 4. Firestore doc `songs/song_diksha_dhaundiyal_pooja_dhaundiyal__main_pahadan` | exists: **true** · audioUrl matches R2: **true** · approvalStatus=pending · reviewRequired=true |
| 5. App catalog (provider source) | present: **true** · slug=`main-pahadan` · searchKeywords→ via title/artist |
| 6. Playback readiness | audioUrl is https + reachable + MP3 bytes → `just_audio` `AudioSource.uri` streams it directly |

## Satpuli Ka Mela

| Stage | Evidence |
|---|---|
| 1. Local MP3 (source of truth) | `Satpuli_ka_Mela___Garhwali_Song___Rohit_Chauhan___Slowed___Reverbed___8D_Song__(256k).mp3` — exists: **true** |
| 2. Enriched metadata | artist=Rohit Chauhan · region=Garhwali/Garhwali · genre=Festival · conf=0.88 |
| 3. R2 upload (audio) | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/satpuli-ka-mela-garhwali-song-rohit-chauhan-slowed-reverbed-8d-song-256k.mp3 |
| 3a. R2 live fetch | HTTP **206** · type `audio/mpeg` · range `bytes 0-2047/6023084` · 2048B · valid MP3 header: **true** |
| 3b. R2 artwork | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/satpuli-ka-mela-garhwali-song-rohit-chauhan-slowed-reverbed-8d-song-256k.png |
| 4. Firestore doc `songs/song_rohit_chauhan__satpuli_ka_mela` | exists: **true** · audioUrl matches R2: **true** · approvalStatus=pending · reviewRequired=true |
| 5. App catalog (provider source) | present: **true** · slug=`satpuli-ka-mela` · searchKeywords→ via title/artist |
| 6. Playback readiness | audioUrl is https + reachable + MP3 bytes → `just_audio` `AudioSource.uri` streams it directly |

## Baadri

| Stage | Evidence |
|---|---|
| 1. Local MP3 (source of truth) | `Baadri___Latest_Pahari_Jaunsari_Dj_Song_2021___Sardar_Singh_Sharma___Himachali_Song____Y_Series___(256k).mp3` — exists: **true** |
| 2. Enriched metadata | artist=Sardar Singh Sharma · region=Jaunsari/Jaunsari · genre=Folk · conf=0.8 |
| 3. R2 upload (audio) | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/baadri-latest-pahari-jaunsari-dj-song-2021-sardar-singh-sharma-himachali-song-y-.mp3 |
| 3a. R2 live fetch | HTTP **206** · type `audio/mpeg` · range `bytes 0-2047/9277100` · 2048B · valid MP3 header: **true** |
| 3b. R2 artwork | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/baadri-latest-pahari-jaunsari-dj-song-2021-sardar-singh-sharma-himachali-song-y-.png |
| 4. Firestore doc `songs/song_sardar_singh_sharma__baadri` | exists: **true** · audioUrl matches R2: **true** · approvalStatus=pending · reviewRequired=true |
| 5. App catalog (provider source) | present: **true** · slug=`baadri` · searchKeywords→ via title/artist |
| 6. Playback readiness | audioUrl is https + reachable + MP3 bytes → `just_audio` `AudioSource.uri` streams it directly |

## Kolang

| Stage | Evidence |
|---|---|
| 1. Local MP3 (source of truth) | `Kolang____Oreio_Beats_Latest_Pahadi_song_2026____Himachali_Song____Palak,Hardik(256k).mp3` — exists: **true** |
| 2. Enriched metadata | artist=Palak, Hardik · region=Himachali/Himachali · genre=Folk · conf=0.8 |
| 3. R2 upload (audio) | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/kolang-oreio-beats-latest-pahadi-song-2026-himachali-song-palak-hardik-256k.mp3 |
| 3a. R2 live fetch | HTTP **206** · type `audio/mpeg` · range `bytes 0-2047/2212652` · 2048B · valid MP3 header: **true** |
| 3b. R2 artwork | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/kolang-oreio-beats-latest-pahadi-song-2026-himachali-song-palak-hardik-256k.png |
| 4. Firestore doc `songs/song_palak_hardik__kolang` | exists: **true** · audioUrl matches R2: **true** · approvalStatus=pending · reviewRequired=true |
| 5. App catalog (provider source) | present: **true** · slug=`kolang` · searchKeywords→ via title/artist |
| 6. Playback readiness | audioUrl is https + reachable + MP3 bytes → `just_audio` `AudioSource.uri` streams it directly |

## Dhire Dhire O Chanda

| Stage | Evidence |
|---|---|
| 1. Local MP3 (source of truth) | `Dhire_Dhire_O_Chanda___Kumauni_Song___Lalit_Mohan_Joshi___Lofi_Song___Slowed___Reverb___#pahadisong(256k).mp3` — exists: **true** |
| 2. Enriched metadata | artist=Lalit Mohan Joshi · region=Kumaoni/Kumaoni · genre=Folk · conf=0.8 |
| 3. R2 upload (audio) | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/audio/dhire-dhire-o-chanda-kumauni-song-lalit-mohan-joshi-lofi-song-slowed-reverb-paha.mp3 |
| 3a. R2 live fetch | HTTP **206** · type `audio/mpeg` · range `bytes 0-2047/7038380` · 2048B · valid MP3 header: **true** |
| 3b. R2 artwork | https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/dhire-dhire-o-chanda-kumauni-song-lalit-mohan-joshi-lofi-song-slowed-reverb-paha.png |
| 4. Firestore doc `songs/song_lalit_mohan_joshi__dhire_dhire_o_chanda` | exists: **true** · audioUrl matches R2: **true** · approvalStatus=pending · reviewRequired=true |
| 5. App catalog (provider source) | present: **true** · slug=`dhire-dhire-o-chanda` · searchKeywords→ via title/artist |
| 6. Playback readiness | audioUrl is https + reachable + MP3 bytes → `just_audio` `AudioSource.uri` streams it directly |

---

## Result

**5/5 songs traced end-to-end.** All R2 audio URLs returned a 2xx status with a valid MP3 byte header, all Firestore docs read back with matching R2 audioUrl, and all appear in the bundled app catalog. Overall: **PASS**.
