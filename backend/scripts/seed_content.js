/**
 * Content Seeder Script
 * Run: node seed_content.js
 *
 * Seeds Firestore with initial Pahadi music catalog structure.
 * Replace placeholder URLs with your actual Firebase Storage URLs.
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'himraag-prod.appspot.com',
});

const db = admin.firestore();

const artists = [
  {
    id: 'narendra_singh_negi',
    name: 'Narendra Singh Negi',
    imageUrl: 'https://storage.googleapis.com/himraag-prod.appspot.com/artists/nsnegi.jpg',
    region: 'Garhwali',
    bio: 'Narendra Singh Negi is a renowned Garhwali folk poet and singer, often called the voice of Uttarakhand.',
    songCount: 0,
    albumCount: 0,
    genres: ['Folk', 'Contemporary Folk'],
    monthlyListeners: 150000,
    isVerified: true,
    socialLinks: {},
  },
  {
    id: 'meena_rana',
    name: 'Meena Rana',
    imageUrl: 'https://storage.googleapis.com/himraag-prod.appspot.com/artists/meena_rana.jpg',
    region: 'Garhwali',
    bio: 'Meena Rana is a celebrated Garhwali singer known for her melodious folk songs.',
    songCount: 0,
    albumCount: 0,
    genres: ['Folk', 'Wedding'],
    monthlyListeners: 80000,
    isVerified: true,
    socialLinks: {},
  },
  {
    id: 'hema_negi_karasi',
    name: 'Hema Negi Karasi',
    imageUrl: 'https://storage.googleapis.com/himraag-prod.appspot.com/artists/hema_negi.jpg',
    region: 'Kumaoni',
    bio: 'Hema Negi Karasi is a prominent Kumaoni folk singer who has popularized Kumaoni music nationwide.',
    songCount: 0,
    albumCount: 0,
    genres: ['Folk', 'Festival'],
    monthlyListeners: 60000,
    isVerified: true,
    socialLinks: {},
  },
];

const albums = [
  {
    id: 'pahadi_ghazals_vol1',
    title: 'Pahadi Ghazals Vol. 1',
    artistId: 'narendra_singh_negi',
    artistName: 'Narendra Singh Negi',
    artworkUrl: 'https://storage.googleapis.com/himraag-prod.appspot.com/artwork/pahadi_ghazals_v1.jpg',
    region: 'Garhwali',
    language: 'Garhwali',
    genre: 'Folk',
    releaseYear: 2022,
    songCount: 8,
    totalDurationMs: 2400000,
    description: 'A collection of soulful Garhwali folk ghazals by the legend NSN.',
    tags: ['folk', 'garhwali', 'ghazal'],
    isApproved: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  },
];

const songs = [
  {
    id: 'bedu_pako_baro_masa',
    title: 'Bedu Pako Baro Masa',
    artistId: 'hema_negi_karasi',
    artistName: 'Hema Negi Karasi',
    albumId: 'pahadi_ghazals_vol1',
    albumTitle: 'Traditional Kumaoni',
    audioUrl: 'https://storage.googleapis.com/himraag-prod.appspot.com/audio/bedu_pako.mp3',
    artworkUrl: 'https://storage.googleapis.com/himraag-prod.appspot.com/artwork/bedu_pako.jpg',
    durationMs: 245000,
    region: 'Kumaoni',
    language: 'Kumaoni',
    genre: 'Folk',
    releaseYear: 2020,
    playCount: 45000,
    tags: ['traditional', 'folk', 'kumaoni', 'seasonal'],
    isApproved: true,
    isDownloadable: true,
    mood: 'Joyful',
    releasedAt: admin.firestore.Timestamp.fromDate(new Date('2020-01-01')),
  },
];

async function seedData() {
  console.log('Starting seed...');

  const batch = db.batch();

  artists.forEach(artist => {
    const ref = db.collection('artists').doc(artist.id);
    batch.set(ref, artist);
  });

  albums.forEach(album => {
    const ref = db.collection('albums').doc(album.id);
    batch.set(ref, album);
  });

  songs.forEach(song => {
    const ref = db.collection('songs').doc(song.id);
    batch.set(ref, song);
  });

  await batch.commit();
  console.log(`Seeded ${artists.length} artists, ${albums.length} albums, ${songs.length} songs`);
  process.exit(0);
}

seedData().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
