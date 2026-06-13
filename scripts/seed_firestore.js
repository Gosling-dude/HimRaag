/**
 * HimRaag Firestore Seed Script
 *
 * Prerequisites:
 *   npm install firebase-admin
 *
 * Usage:
 *   node scripts/seed_firestore.js
 *
 * Requires:
 *   GOOGLE_APPLICATION_CREDENTIALS env var pointing to a service account JSON.
 *   Or: set serviceAccountPath below to the path of your service account JSON.
 *
 * NOTE: Audio URLs use placeholder paths. Replace with real Firebase Storage URLs
 *       after uploading actual audio files.
 */

const admin = require('firebase-admin');

// ─── Initialize ───────────────────────────────────────────────────────────────

const serviceAccount = process.env.GOOGLE_APPLICATION_CREDENTIALS
  ? require(process.env.GOOGLE_APPLICATION_CREDENTIALS)
  : null;

if (!serviceAccount) {
  console.error(
    'ERROR: Set GOOGLE_APPLICATION_CREDENTIALS to the path of your service account JSON.\n' +
    'Download from: Firebase Console → Project Settings → Service Accounts → Generate new private key'
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'himraag-prod',
  storageBucket: 'himraag-prod.firebasestorage.app',
});

const db = admin.firestore();
const storage = admin.storage().bucket();

// ─── Helper ───────────────────────────────────────────────────────────────────

async function upsert(collection, id, data) {
  await db.collection(collection).doc(id).set(data, { merge: true });
  console.log(`  ✓ ${collection}/${id}`);
}

// ─── Artists ──────────────────────────────────────────────────────────────────

const artists = [
  {
    id: 'artist_narendra_singh_negi',
    name: 'Narendra Singh Negi',
    nameLowercase: 'narendra singh negi',
    imageUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artists%2Fnarendra_singh_negi.jpg?alt=media',
    region: 'Garhwali',
    bio: 'Narendra Singh Negi is the most celebrated Garhwali folk singer and lyricist, known as the voice of Uttarakhand.',
    songCount: 200,
    albumCount: 20,
    genres: ['Folk', 'Devotional', 'Contemporary Folk'],
    monthlyListeners: 50000,
    isVerified: true,
    socialLinks: {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'artist_meena_rana',
    name: 'Meena Rana',
    nameLowercase: 'meena rana',
    imageUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artists%2Fmeena_rana.jpg?alt=media',
    region: 'Garhwali',
    bio: 'Meena Rana is one of the finest female voices in Uttarakhandi folk music.',
    songCount: 80,
    albumCount: 8,
    genres: ['Folk', 'Festival', 'Wedding'],
    monthlyListeners: 25000,
    isVerified: true,
    socialLinks: {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'artist_pritam_bharatwan',
    name: 'Pritam Bharatwan',
    nameLowercase: 'pritam bharatwan',
    imageUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artists%2Fpritam_bharatwan.jpg?alt=media',
    region: 'Garhwali',
    bio: 'Pritam Bharatwan is known for his soulful Garhwali ballads and has won numerous state awards.',
    songCount: 60,
    albumCount: 6,
    genres: ['Folk', 'Devotional'],
    monthlyListeners: 20000,
    isVerified: true,
    socialLinks: {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'artist_hema_negi_karasi',
    name: 'Hema Negi Karasi',
    nameLowercase: 'hema negi karasi',
    imageUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artists%2Fhema_negi_karasi.jpg?alt=media',
    region: 'Kumaoni',
    bio: 'Hema Negi Karasi is a Padma Shri awardee who has kept Kumaoni folk music alive across generations.',
    songCount: 100,
    albumCount: 10,
    genres: ['Folk', 'Devotional', 'Festival'],
    monthlyListeners: 30000,
    isVerified: true,
    socialLinks: {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'artist_mohan_upreti',
    name: 'Mohan Upreti',
    nameLowercase: 'mohan upreti',
    imageUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artists%2Fmohan_upreti.jpg?alt=media',
    region: 'Kumaoni',
    bio: 'Mohan Upreti was a pioneer who brought Kumaoni folk music to national and international audiences.',
    songCount: 70,
    albumCount: 7,
    genres: ['Folk', 'Instrumental'],
    monthlyListeners: 18000,
    isVerified: true,
    socialLinks: {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
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
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fpahadi_jhankar.jpg?alt=media',
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Folk',
    releaseYear: 2010,
    songCount: 8,
    totalDurationMs: 2880000,
    description: 'A collection of timeless Garhwali folk songs by the legendary Narendra Singh Negi.',
    tags: ['garhwali', 'folk', 'classic'],
    isApproved: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'album_kumaoni_doli',
    title: 'Kumaoni Doli',
    titleLowercase: 'kumaoni doli',
    artistId: 'artist_hema_negi_karasi',
    artistName: 'Hema Negi Karasi',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fkumaoni_doli.jpg?alt=media',
    region: 'Kumaoni',
    language: 'Kumaoni',
    genre: 'Folk',
    releaseYear: 2015,
    songCount: 6,
    totalDurationMs: 2100000,
    description: 'Wedding songs from the Kumaon hills by Padma Shri Hema Negi Karasi.',
    tags: ['kumaoni', 'wedding', 'folk'],
    isApproved: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'album_garhwali_bhakti',
    title: 'Garhwali Bhakti Sangeet',
    titleLowercase: 'garhwali bhakti sangeet',
    artistId: 'artist_pritam_bharatwan',
    artistName: 'Pritam Bharatwan',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fgarhwali_bhakti.jpg?alt=media',
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Devotional',
    releaseYear: 2018,
    songCount: 10,
    totalDurationMs: 3600000,
    description: 'Devotional songs dedicated to the deities of the Himalayas.',
    tags: ['garhwali', 'devotional', 'bhakti'],
    isApproved: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

// ─── Songs ────────────────────────────────────────────────────────────────────

const now = admin.firestore.Timestamp.now();

const songs = [
  {
    id: 'song_bedu_pako',
    title: 'Bedu Pako Baramasa',
    titleLowercase: 'bedu pako baramasa',
    artistId: 'artist_narendra_singh_negi',
    artistName: 'Narendra Singh Negi',
    albumId: 'album_pahadi_jhankar',
    albumTitle: 'Pahadi Jhankar',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_bedu_pako.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fpahadi_jhankar.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_ghogholi',
    title: 'Ghogholi',
    titleLowercase: 'ghogholi',
    artistId: 'artist_narendra_singh_negi',
    artistName: 'Narendra Singh Negi',
    albumId: 'album_pahadi_jhankar',
    albumTitle: 'Pahadi Jhankar',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_ghogholi.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fpahadi_jhankar.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_raniban',
    title: 'Raniban',
    titleLowercase: 'raniban',
    artistId: 'artist_meena_rana',
    artistName: 'Meena Rana',
    albumId: '',
    albumTitle: '',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_raniban.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Franiban.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_nyoli',
    title: 'Nyoli',
    titleLowercase: 'nyoli',
    artistId: 'artist_hema_negi_karasi',
    artistName: 'Hema Negi Karasi',
    albumId: 'album_kumaoni_doli',
    albumTitle: 'Kumaoni Doli',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_nyoli.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fkumaoni_doli.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_chholia',
    title: 'Chholia',
    titleLowercase: 'chholia',
    artistId: 'artist_hema_negi_karasi',
    artistName: 'Hema Negi Karasi',
    albumId: 'album_kumaoni_doli',
    albumTitle: 'Kumaoni Doli',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_chholia.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fkumaoni_doli.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_bhagwati_stuti',
    title: 'Bhagwati Stuti',
    titleLowercase: 'bhagwati stuti',
    artistId: 'artist_pritam_bharatwan',
    artistName: 'Pritam Bharatwan',
    albumId: 'album_garhwali_bhakti',
    albumTitle: 'Garhwali Bhakti Sangeet',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_bhagwati_stuti.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fgarhwali_bhakti.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_pahadi_dil',
    title: 'Pahadi Dil',
    titleLowercase: 'pahadi dil',
    artistId: 'artist_pritam_bharatwan',
    artistName: 'Pritam Bharatwan',
    albumId: 'album_garhwali_bhakti',
    albumTitle: 'Garhwali Bhakti Sangeet',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_pahadi_dil.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fgarhwali_bhakti.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_basant_aayo',
    title: 'Basant Aayo Re',
    titleLowercase: 'basant aayo re',
    artistId: 'artist_meena_rana',
    artistName: 'Meena Rana',
    albumId: '',
    albumTitle: '',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_basant_aayo.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fbasant_aayo.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_kumaoni_holi',
    title: 'Kumaoni Holi Geet',
    titleLowercase: 'kumaoni holi geet',
    artistId: 'artist_mohan_upreti',
    artistName: 'Mohan Upreti',
    albumId: '',
    albumTitle: '',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_kumaoni_holi.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fkumaoni_holi.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
  {
    id: 'song_jaunsari_naati',
    title: 'Jaunsari Naati',
    titleLowercase: 'jaunsari naati',
    artistId: 'artist_narendra_singh_negi',
    artistName: 'Narendra Singh Negi',
    albumId: '',
    albumTitle: '',
    audioUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/audio%2Fsong_jaunsari_naati.mp3?alt=media',
    artworkUrl: 'https://firebasestorage.googleapis.com/v0/b/himraag-prod.firebasestorage.app/o/artwork%2Fjaunsari_naati.jpg?alt=media',
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
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

// ─── Categories ───────────────────────────────────────────────────────────────

const categories = [
  { id: 'folk', name: 'Folk', icon: 'music_note', color: '#6B3FA0' },
  { id: 'devotional', name: 'Devotional', icon: 'self_improvement', color: '#E8A020' },
  { id: 'festival', name: 'Festival', icon: 'celebration', color: '#2E7D32' },
  { id: 'wedding', name: 'Wedding', icon: 'favorite', color: '#C62828' },
  { id: 'seasonal', name: 'Seasonal', icon: 'wb_sunny', color: '#F57F17' },
  { id: 'instrumental', name: 'Instrumental', icon: 'piano', color: '#1565C0' },
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

  console.log('\n✅ Seeding complete!\n');
  console.log('NEXT STEPS:');
  console.log('  1. Upload MP3 files to Firebase Storage under: audio/<songId>.mp3');
  console.log('  2. Upload artwork JPGs under: artwork/<albumId>.jpg');
  console.log('  3. Upload artist images under: artists/<artistId>.jpg');
  console.log('  4. Update song/album audioUrl and artworkUrl fields with real Storage URLs');
  console.log('  5. Deploy Firestore rules: firebase deploy --only firestore:rules');
  console.log('  6. Deploy Firestore indexes: firebase deploy --only firestore:indexes');
  console.log('  7. Deploy Storage rules: firebase deploy --only storage');
}

seed().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
