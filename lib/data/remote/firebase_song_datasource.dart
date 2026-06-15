import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/content_constants.dart';
import '../../core/constants/firebase_constants.dart';
import '../../domain/models/song.dart';
import 'dto/song_dto.dart';

class FirebaseSongDatasource {
  FirebaseSongDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _songs =>
      _firestore.collection(FirebaseConstants.songsCollection);

  // Compound queries (where + orderBy on different field) require composite
  // indexes that may not exist. Fetch with a single equality filter and sort
  // client-side to avoid FAILED_PRECONDITION errors.

  Future<List<Song>> getFeaturedSongs({int limit = 10}) async {
    try {
      debugPrint('[FIRESTORE] getFeaturedSongs: fetching');
      final snapshot = await _songs
          .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
          .limit(limit * 2)
          .get();
      final songs = snapshot.docs
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      debugPrint('[FIRESTORE] getFeaturedSongs: got ${songs.length} songs');
      return songs.take(limit).toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getFeaturedSongs ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Song>> getTrendingSongs({int limit = 20}) async {
    try {
      debugPrint('[FIRESTORE] getTrendingSongs: fetching');
      final snapshot = await _songs
          .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
          .limit(50)
          .get();
      final songs = snapshot.docs
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      debugPrint('[FIRESTORE] getTrendingSongs: got ${songs.length} songs');
      return songs.take(limit).toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getTrendingSongs ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Song>> getNewReleases({int limit = 20}) async {
    try {
      debugPrint('[FIRESTORE] getNewReleases: fetching');
      final snapshot = await _songs
          .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
          .limit(50)
          .get();
      final songs = snapshot.docs
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.releaseYear.compareTo(a.releaseYear));
      debugPrint('[FIRESTORE] getNewReleases: got ${songs.length} songs');
      return songs.take(limit).toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getNewReleases ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Song>> getSongsByRegion(String region, {int limit = 30}) async {
    try {
      debugPrint('[FIRESTORE] getSongsByRegion($region): fetching');
      final snapshot = await _songs
          .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
          .where(FirebaseConstants.songsRegionField, isEqualTo: region)
          .limit(limit)
          .get();
      final songs = snapshot.docs
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      debugPrint('[FIRESTORE] getSongsByRegion: got ${songs.length} songs');
      return songs;
    } catch (e, st) {
      debugPrint('[FIRESTORE] getSongsByRegion ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Song>> getSongsByAlbum(String albumId) async {
    try {
      debugPrint('[FIRESTORE] getSongsByAlbum($albumId): fetching');
      final snapshot = await _songs
          .where(FirebaseConstants.songsAlbumField, isEqualTo: albumId)
          .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
          .get();
      final songs = snapshot.docs
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .toList();
      debugPrint('[FIRESTORE] getSongsByAlbum: got ${songs.length} songs');
      return songs;
    } catch (e, st) {
      debugPrint('[FIRESTORE] getSongsByAlbum ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Song>> getSongsByArtist(String artistId, {int limit = 50}) async {
    try {
      debugPrint('[FIRESTORE] getSongsByArtist($artistId): fetching');
      final snapshot = await _songs
          .where(FirebaseConstants.songsArtistField, isEqualTo: artistId)
          .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
          .limit(limit)
          .get();
      final songs = snapshot.docs
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
      debugPrint('[FIRESTORE] getSongsByArtist: got ${songs.length} songs');
      return songs;
    } catch (e, st) {
      debugPrint('[FIRESTORE] getSongsByArtist ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Song>> getSongsByGenre(String genre, {int limit = 30}) async {
    try {
      final snapshot = await _songs
          .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
          .where(FirebaseConstants.songsGenreField, isEqualTo: genre)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.playCount.compareTo(a.playCount));
    } catch (e, st) {
      debugPrint('[FIRESTORE] getSongsByGenre ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Song>> getSongsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final futures = ids.map((id) => _songs.doc(id).get()).toList();
      final snapshots = await Future.wait(futures);
      return snapshots
          .where((doc) => doc.exists)
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getSongsByIds ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<Song?> getSongById(String id) async {
    try {
      final doc = await _songs.doc(id).get();
      if (!doc.exists) return null;
      return SongDto.fromFirestore(doc).toDomain();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getSongById ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<void> incrementPlayCount(String songId) async {
    try {
      await _songs.doc(songId).update({
        FirebaseConstants.songsPopularityField: FieldValue.increment(1),
      });
    } catch (e) {
      // Silently fails for unauthenticated users — non-critical
      debugPrint('[FIRESTORE] incrementPlayCount skipped (guest mode): $e');
    }
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

  // ── Admin / content-management operations ────────────────────────────────
  // These are used by the Flutter Web admin dashboard. Reads are unfiltered
  // (no isApproved gate) so moderators can see pending/rejected/demo content.
  // Writes are guarded by Firestore security rules (admin custom claim).

  /// Fetch the full catalog for the admin tables, newest first by title.
  /// Paginated via [limit]/[startAfterTitle] (orders by titleLowercase).
  Future<List<Song>> getAllSongsForAdmin({
    int limit = 200,
    String? startAfterTitle,
  }) async {
    Query<Map<String, dynamic>> q =
        _songs.orderBy('titleLowercase').limit(limit);
    if (startAfterTitle != null) {
      q = q.startAfter([startAfterTitle.toLowerCase()]);
    }
    final snapshot = await q.get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<void> upsertSong(Song song) async {
    final dto = SongDto.fromDomain(song);
    await _songs.doc(song.id).set(
      {...dto.toFirestore(), 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> setApprovalStatus(String songId, ApprovalStatus status) async {
    await _songs.doc(songId).update({
      'approvalStatus': status.wire,
      'isApproved': status.isApproved,
      // Approving publishes; any other state un-publishes.
      'isPublished': status.isApproved,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSong(String songId) async {
    await _songs.doc(songId).delete();
  }
}
