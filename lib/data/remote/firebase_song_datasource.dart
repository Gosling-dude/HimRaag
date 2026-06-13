import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';
import '../../domain/models/song.dart';
import 'dto/song_dto.dart';

class FirebaseSongDatasource {
  FirebaseSongDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _songs =>
      _firestore.collection(FirebaseConstants.songsCollection);

  Future<List<Song>> getFeaturedSongs({int limit = 10}) async {
    final snapshot = await _songs
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .orderBy(FirebaseConstants.songsPopularityField, descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Song>> getTrendingSongs({int limit = 20}) async {
    final snapshot = await _songs
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .orderBy(FirebaseConstants.songsPopularityField, descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Song>> getNewReleases({int limit = 20}) async {
    final snapshot = await _songs
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .orderBy(FirebaseConstants.songsReleasedAtField, descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Song>> getSongsByRegion(String region, {int limit = 30}) async {
    final snapshot = await _songs
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .where(FirebaseConstants.songsRegionField, isEqualTo: region)
        .orderBy(FirebaseConstants.songsPopularityField, descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Song>> getSongsByAlbum(String albumId) async {
    final snapshot = await _songs
        .where(FirebaseConstants.songsAlbumField, isEqualTo: albumId)
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Song>> getSongsByArtist(String artistId, {int limit = 50}) async {
    final snapshot = await _songs
        .where(FirebaseConstants.songsArtistField, isEqualTo: artistId)
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .orderBy(FirebaseConstants.songsPopularityField, descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Song>> getSongsByGenre(String genre, {int limit = 30}) async {
    final snapshot = await _songs
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .where(FirebaseConstants.songsGenreField, isEqualTo: genre)
        .orderBy(FirebaseConstants.songsPopularityField, descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Song>> getSongsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final futures = ids.map((id) => _songs.doc(id).get()).toList();
    final snapshots = await Future.wait(futures);
    return snapshots
        .where((doc) => doc.exists)
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<Song?> getSongById(String id) async {
    final doc = await _songs.doc(id).get();
    if (!doc.exists) return null;
    return SongDto.fromFirestore(doc).toDomain();
  }

  Future<void> incrementPlayCount(String songId) async {
    await _songs.doc(songId).update({
      FirebaseConstants.songsPopularityField: FieldValue.increment(1),
    });
  }

  Stream<List<Song>> watchSongsByAlbum(String albumId) {
    return _songs
        .where(FirebaseConstants.songsAlbumField, isEqualTo: albumId)
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SongDto.fromFirestore(doc).toDomain())
            .toList());
  }
}
