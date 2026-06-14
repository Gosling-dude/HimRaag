/**
 * HimRaag Firestore Seed Script
 *
 * Prerequisites:
 *   npm install firebase-admin
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json node scripts/seed_firestore.js
 *
 * Audio URLs point to SoundHelix royalty-free samples (for development/demo).
 * Image URLs use picsum.photos with seeded IDs (consistent, placeholder images).
 *
 * To migrate to real Firebase Storage:
 *   1. Upload MP3s to gs://himraag-prod.firebasestorage.app/audio/<songId>.mp3
 *   2. Upload artwork to gs://himraag-prod.firebasestorage.app/artwork/<albumId>.jpg
 *   3. Upload artist images to gs://himraag-prod.firebasestorage.app/artists/<artistId>.jpg
 *   4. Run this script again after updating the URL constants below.
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');

// ─── Initialize ───────────────────────────────────────────────────────────────

const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
const serviceAccount = serviceAccountPath
  ? JSON.parse(require('fs').readFileSync(serviceAccountPath, 'utf8'))
  : null;

if (!serviceAccount) {
  console.error(
    'ERROR: Set GOOGLE_APPLICATION_CREDENTIALS to the path of your service account JSON.\n' +
    'Download from: Firebase Console → Project Settings → Service Accounts → Generate new private key'
  );
  process.exit(1);
}

initializeApp({
  credential: cert(serviceAccount),
  projectId: 'himraag-prod',
});

const db = getFirestore();

// ─── Helper ───────────────────────────────────────────────────────────────────

async function upsert(collection, id, data) {
  await db.collection(collection).doc(id).set(data, { merge: true });
  console.log(`  ✓ ${collection}/${id}`);
}

// ─── URL Constants ───────────────────────────────────────────────────────────
// SoundHelix: royalty-free, publicly accessible MP3 samples
// picsum.photos: seeded placeholder images (same seed = same image always)

const AUDIO = {
  song_bedu_pako:      'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
  song_ghogholi:       'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
  song_raniban:        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
  song_nyoli:          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
  song_chholia:        'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
  song_bhagwati_stuti: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-6.mp3',
  song_pahadi_dil:     'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-7.mp3',
  song_basant_aayo:    'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-8.mp3',
  song_kumaoni_holi:   'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-9.mp3',
  song_jaunsari_naati: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-10.mp3',
};

const ART = {
  album_pahadi_jhankar:  'https://picsum.photos/seed/pahadi_jhankar/500/500',
  album_kumaoni_doli:    'https://picsum.photos/seed/kumaoni_doli/500/500',
  album_garhwali_bhakti: 'https://picsum.photos/seed/garhwali_bhakti/500/500',
  song_raniban:          'https://picsum.photos/seed/raniban/500/500',
  song_basant_aayo:      'https://picsum.photos/seed/basant_aayo/500/500',
  song_kumaoni_holi:     'https://picsum.photos/seed/kumaoni_holi/500/500',
  song_jaunsari_naati:   'https://picsum.photos/seed/jaunsari_naati/500/500',
};

const IMG = {
  artist_narendra_singh_negi: 'https://picsum.photos/seed/negi/400/400',
  artist_meena_rana:          'https://picsum.photos/seed/meena/400/400',
  artist_pritam_bharatwan:    'https://picsum.photos/seed/pritam/400/400',
  artist_hema_negi_karasi:    'https://picsum.photos/seed/hema/400/400',
  artist_mohan_upreti:        'https://picsum.photos/seed/mohan/400/400',
};

// ─── Artists ──────────────────────────────────────────────────────────────────

const artists = [
  {
    id: 'artist_narendra_singh_negi',
    name: 'Narendra Singh Negi',
    nameLowercase: 'narendra singh negi',
    imageUrl: IMG.artist_narendra_singh_negi,
    region: 'Garhwali',
    bio: 'Narendra Singh Negi is the most celebrated Garhwali folk singer and lyricist, known as the voice of Uttarakhand.',
    songCount: 200,
    albumCount: 20,
    genres: ['Folk', 'Devotional', 'Contemporary Folk'],
    monthlyListeners: 50000,
    isVerified: true,
    socialLinks: {},
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'artist_meena_rana',
    name: 'Meena Rana',
    nameLowercase: 'meena rana',
    imageUrl: IMG.artist_meena_rana,
    region: 'Garhwali',
    bio: 'Meena Rana is one of the finest female voices in Uttarakhandi folk music.',
    songCount: 80,
    albumCount: 8,
    genres: ['Folk', 'Festival', 'Wedding'],
    monthlyListeners: 25000,
    isVerified: true,
    socialLinks: {},
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'artist_pritam_bharatwan',
    name: 'Pritam Bharatwan',
    nameLowercase: 'pritam bharatwan',
    imageUrl: IMG.artist_pritam_bharatwan,
    region: 'Garhwali',
    bio: 'Pritam Bharatwan is known for his soulful Garhwali ballads and has won numerous state awards.',
    songCount: 60,
    albumCount: 6,
    genres: ['Folk', 'Devotional'],
    monthlyListeners: 20000,
    isVerified: true,
    socialLinks: {},
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'artist_hema_negi_karasi',
    name: 'Hema Negi Karasi',
    nameLowercase: 'hema negi karasi',
    imageUrl: IMG.artist_hema_negi_karasi,
    region: 'Kumaoni',
    bio: 'Hema Negi Karasi is a Padma Shri awardee who has kept Kumaoni folk music alive across generations.',
    songCount: 100,
    albumCount: 10,
    genres: ['Folk', 'Devotional', 'Festival'],
    monthlyListeners: 30000,
    isVerified: true,
    socialLinks: {},
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'artist_mohan_upreti',
    name: 'Mohan Upreti',
    nameLowercase: 'mohan upreti',
    imageUrl: IMG.artist_mohan_upreti,
    region: 'Kumaoni',
    bio: 'Mohan Upreti was a pioneer who brought Kumaoni folk music to national and international audiences.',
    songCount: 70,
    albumCount: 7,
    genres: ['Folk', 'Instrumental'],
    monthlyListeners: 18000,
    isVerified: true,
    socialLinks: {},
    createdAt: FieldValue.serverTimestamp(),
  },
];

// ─── Albums ───────────────────────────────────────────────────────────────────

const albums = [
  {
    id: 'album_pahadi_jhankar',
    title: 'Pahadi Jhankar',
    titleLowercase: 'pahadi jhankar',
    artistId: 'artist_narendra_singh_negi',
    artistName: 'Narendra Singh Negi',
    artworkUrl: ART.album_pahadi_jhankar,
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Folk',
    releaseYear: 2010,
    songCount: 8,
    totalDurationMs: 2880000,
    description: 'A collection of timeless Garhwali folk songs by the legendary Narendra Singh Negi.',
    tags: ['garhwali', 'folk', 'classic'],
    isApproved: true,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'album_kumaoni_doli',
    title: 'Kumaoni Doli',
    titleLowercase: 'kumaoni doli',
    artistId: 'artist_hema_negi_karasi',
    artistName: 'Hema Negi Karasi',
    artworkUrl: ART.album_kumaoni_doli,
    region: 'Kumaoni',
    language: 'Kumaoni',
    genre: 'Folk',
    releaseYear: 2015,
    songCount: 6,
    totalDurationMs: 2100000,
    description: 'Wedding songs from the Kumaon hills by Padma Shri Hema Negi Karasi.',
    tags: ['kumaoni', 'wedding', 'folk'],
    isApproved: true,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'album_garhwali_bhakti',
    title: 'Garhwali Bhakti Sangeet',
    titleLowercase: 'garhwali bhakti sangeet',
    artistId: 'artist_pritam_bharatwan',
    artistName: 'Pritam Bharatwan',
    artworkUrl: ART.album_garhwali_bhakti,
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Devotional',
    releaseYear: 2018,
    songCount: 10,
    totalDurationMs: 3600000,
    description: 'Devotional songs dedicated to the deities of the Himalayas.',
    tags: ['garhwali', 'devotional', 'bhakti'],
    isApproved: true,
    createdAt: FieldValue.serverTimestamp(),
  },
];

// ─── Songs ────────────────────────────────────────────────────────────────────

const now = Timestamp.now();

const songs = [
  {
    id: 'song_bedu_pako',
    title: 'Bedu Pako Baramasa',
    titleLowercase: 'bedu pako baramasa',
    artistId: 'artist_narendra_singh_negi',
    artistName: 'Narendra Singh Negi',
    albumId: 'album_pahadi_jhankar',
    albumTitle: 'Pahadi Jhankar',
    audioUrl: AUDIO.song_bedu_pako,
    artworkUrl: ART.album_pahadi_jhankar,
    durationMs: 324000,
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Folk',
    releaseYear: 2010,
    playCount: 15000,
    tags: ['classic', 'folk', 'garhwali', 'harvest'],
    isApproved: true,
    isDownloadable: true,
    mood: 'joyful',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_ghogholi',
    title: 'Ghogholi',
    titleLowercase: 'ghogholi',
    artistId: 'artist_narendra_singh_negi',
    artistName: 'Narendra Singh Negi',
    albumId: 'album_pahadi_jhankar',
    albumTitle: 'Pahadi Jhankar',
    audioUrl: AUDIO.song_ghogholi,
    artworkUrl: ART.album_pahadi_jhankar,
    durationMs: 285000,
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Folk',
    releaseYear: 2010,
    playCount: 12000,
    tags: ['folk', 'garhwali'],
    isApproved: true,
    isDownloadable: true,
    mood: 'joyful',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_raniban',
    title: 'Raniban',
    titleLowercase: 'raniban',
    artistId: 'artist_meena_rana',
    artistName: 'Meena Rana',
    albumId: '',
    albumTitle: '',
    audioUrl: AUDIO.song_raniban,
    artworkUrl: ART.song_raniban,
    durationMs: 256000,
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Folk',
    releaseYear: 2019,
    playCount: 8000,
    tags: ['folk', 'garhwali', 'nature'],
    isApproved: true,
    isDownloadable: true,
    mood: 'peaceful',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_nyoli',
    title: 'Nyoli',
    titleLowercase: 'nyoli',
    artistId: 'artist_hema_negi_karasi',
    artistName: 'Hema Negi Karasi',
    albumId: 'album_kumaoni_doli',
    albumTitle: 'Kumaoni Doli',
    audioUrl: AUDIO.song_nyoli,
    artworkUrl: ART.album_kumaoni_doli,
    durationMs: 315000,
    region: 'Kumaoni',
    language: 'Kumaoni',
    genre: 'Folk',
    releaseYear: 2015,
    playCount: 10000,
    tags: ['kumaoni', 'folk', 'wedding'],
    isApproved: true,
    isDownloadable: true,
    mood: 'melancholic',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_chholia',
    title: 'Chholia',
    titleLowercase: 'chholia',
    artistId: 'artist_hema_negi_karasi',
    artistName: 'Hema Negi Karasi',
    albumId: 'album_kumaoni_doli',
    albumTitle: 'Kumaoni Doli',
    audioUrl: AUDIO.song_chholia,
    artworkUrl: ART.album_kumaoni_doli,
    durationMs: 290000,
    region: 'Kumaoni',
    language: 'Kumaoni',
    genre: 'Folk',
    releaseYear: 2015,
    playCount: 9000,
    tags: ['kumaoni', 'folk'],
    isApproved: true,
    isDownloadable: true,
    mood: 'celebratory',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_bhagwati_stuti',
    title: 'Bhagwati Stuti',
    titleLowercase: 'bhagwati stuti',
    artistId: 'artist_pritam_bharatwan',
    artistName: 'Pritam Bharatwan',
    albumId: 'album_garhwali_bhakti',
    albumTitle: 'Garhwali Bhakti Sangeet',
    audioUrl: AUDIO.song_bhagwati_stuti,
    artworkUrl: ART.album_garhwali_bhakti,
    durationMs: 420000,
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Devotional',
    releaseYear: 2018,
    playCount: 20000,
    tags: ['devotional', 'garhwali', 'bhakti', 'goddess'],
    isApproved: true,
    isDownloadable: true,
    mood: 'devotional',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_pahadi_dil',
    title: 'Pahadi Dil',
    titleLowercase: 'pahadi dil',
    artistId: 'artist_pritam_bharatwan',
    artistName: 'Pritam Bharatwan',
    albumId: 'album_garhwali_bhakti',
    albumTitle: 'Garhwali Bhakti Sangeet',
    audioUrl: AUDIO.song_pahadi_dil,
    artworkUrl: ART.album_garhwali_bhakti,
    durationMs: 310000,
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Contemporary Folk',
    releaseYear: 2018,
    playCount: 5000,
    tags: ['contemporary', 'garhwali', 'folk'],
    isApproved: true,
    isDownloadable: true,
    mood: 'nostalgic',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_basant_aayo',
    title: 'Basant Aayo Re',
    titleLowercase: 'basant aayo re',
    artistId: 'artist_meena_rana',
    artistName: 'Meena Rana',
    albumId: '',
    albumTitle: '',
    audioUrl: AUDIO.song_basant_aayo,
    artworkUrl: ART.song_basant_aayo,
    durationMs: 245000,
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Seasonal',
    releaseYear: 2021,
    playCount: 7000,
    tags: ['seasonal', 'spring', 'garhwali', 'festival'],
    isApproved: true,
    isDownloadable: true,
    mood: 'joyful',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_kumaoni_holi',
    title: 'Kumaoni Holi Geet',
    titleLowercase: 'kumaoni holi geet',
    artistId: 'artist_mohan_upreti',
    artistName: 'Mohan Upreti',
    albumId: '',
    albumTitle: '',
    audioUrl: AUDIO.song_kumaoni_holi,
    artworkUrl: ART.song_kumaoni_holi,
    durationMs: 198000,
    region: 'Kumaoni',
    language: 'Kumaoni',
    genre: 'Festival',
    releaseYear: 2005,
    playCount: 11000,
    tags: ['kumaoni', 'holi', 'festival'],
    isApproved: true,
    isDownloadable: true,
    mood: 'celebratory',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
  {
    id: 'song_jaunsari_naati',
    title: 'Jaunsari Naati',
    titleLowercase: 'jaunsari naati',
    artistId: 'artist_narendra_singh_negi',
    artistName: 'Narendra Singh Negi',
    albumId: '',
    albumTitle: '',
    audioUrl: AUDIO.song_jaunsari_naati,
    artworkUrl: ART.song_jaunsari_naati,
    durationMs: 360000,
    region: 'Jaunsari',
    language: 'Jaunsari',
    genre: 'Folk',
    releaseYear: 2012,
    playCount: 6000,
    tags: ['jaunsari', 'folk', 'dance'],
    isApproved: true,
    isDownloadable: true,
    mood: 'energetic',
    releasedAt: now,
    createdAt: FieldValue.serverTimestamp(),
  },
];

// ─── Categories ───────────────────────────────────────────────────────────────

const categories = [
  { id: 'folk',         name: 'Folk',         icon: 'music_note',      color: '#6B3FA0' },
  { id: 'devotional',  name: 'Devotional',   icon: 'self_improvement', color: '#E8A020' },
  { id: 'festival',    name: 'Festival',     icon: 'celebration',      color: '#2E7D32' },
  { id: 'wedding',     name: 'Wedding',      icon: 'favorite',         color: '#C62828' },
  { id: 'seasonal',    name: 'Seasonal',     icon: 'wb_sunny',         color: '#F57F17' },
  { id: 'instrumental',name: 'Instrumental', icon: 'piano',            color: '#1565C0' },
];

// ─── Run ─────────────────────────────────────────────────────────────────────

async function seed() {
  console.log('🌱 Seeding HimRaag Firestore (project: himraag-prod)\n');

  console.log('Artists:');
  for (const artist of artists) {
    const { id, ...data } = artist;
    await upsert('artists', id, data);
  }

  console.log('\nAlbums:');
  for (const album of albums) {
    const { id, ...data } = album;
    await upsert('albums', id, data);
  }

  console.log('\nSongs:');
  for (const song of songs) {
    const { id, ...data } = song;
    await upsert('songs', id, data);
  }

  console.log('\nCategories:');
  for (const cat of categories) {
    const { id, ...data } = cat;
    await upsert('categories', id, data);
  }

  console.log('\n✅ Seeding complete!');
  console.log('\nCurrent audio URLs: SoundHelix royalty-free samples');
  console.log('Current image URLs: picsum.photos placeholder images');
  console.log('\nTo migrate to Firebase Storage (requires Blaze plan):');
  console.log('  1. Enable Storage at: https://console.firebase.google.com/project/himraag-prod/storage');
  console.log('  2. Upload real MP3s to: gs://himraag-prod.firebasestorage.app/audio/<songId>.mp3');
  console.log('  3. Upload artwork to:  gs://himraag-prod.firebasestorage.app/artwork/<albumId>.jpg');
  console.log('  4. Upload artist images: gs://himraag-prod.firebasestorage.app/artists/<artistId>.jpg');
  console.log('  5. Update AUDIO/ART/IMG constants in this file with Firebase Storage URLs');
  console.log('  6. Re-run: GOOGLE_APPLICATION_CREDENTIALS=... node scripts/seed_firestore.js');
}

seed().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
