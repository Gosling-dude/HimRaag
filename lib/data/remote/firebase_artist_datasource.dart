import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firebase_constants.dart';
import '../../domain/models/artist.dart';
import 'dto/artist_dto.dart';

class FirebaseArtistDatasource {
  FirebaseArtistDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _artists =>
      _firestore.collection(FirebaseConstants.artistsCollection);

  Future<List<Artist>> getFeaturedArtists({int limit = 10}) async {
    try {
      debugPrint('[FIRESTORE] getFeaturedArtists: fetching');
      // Single equality filter only — no composite index required.
      final snapshot = await _artists
          .where('isVerified', isEqualTo: true)
          .limit(limit * 2)
          .get();
      final artists = snapshot.docs
          .map((doc) => ArtistDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.monthlyListeners.compareTo(a.monthlyListeners));
      debugPrint('[FIRESTORE] getFeaturedArtists: got ${artists.length} artists');
      return artists.take(limit).toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getFeaturedArtists ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<Artist?> getArtistById(String id) async {
    try {
      debugPrint('[FIRESTORE] getArtistById($id): fetching');
      final doc = await _artists.doc(id).get();
      if (!doc.exists) return null;
      return ArtistDto.fromFirestore(doc).toDomain();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getArtistById ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Artist>> getArtistsByRegion(String region,
      {int limit = 20}) async {
    try {
      final snapshot =
          await _artists.where('region', isEqualTo: region).limit(limit).get();
      return snapshot.docs
          .map((doc) => ArtistDto.fromFirestore(doc).toDomain())
          .toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getArtistsByRegion ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Artist>> getArtistsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final futures = ids.map((id) => _artists.doc(id).get()).toList();
      final snapshots = await Future.wait(futures);
      return snapshots
          .where((doc) => doc.exists)
          .map((doc) => ArtistDto.fromFirestore(doc).toDomain())
          .toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getArtistsByIds ERROR: $e\n$st');
      rethrow;
    }
  }
}
