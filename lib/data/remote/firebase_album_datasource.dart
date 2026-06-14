import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/firebase_constants.dart';
import '../../domain/models/album.dart';
import 'dto/album_dto.dart';

class FirebaseAlbumDatasource {
  FirebaseAlbumDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _albums =>
      _firestore.collection(FirebaseConstants.albumsCollection);

  Future<List<Album>> getFeaturedAlbums({int limit = 10}) async {
    try {
      debugPrint('[FIRESTORE] getFeaturedAlbums: fetching');
      // Single equality filter only — no composite index required.
      final snapshot = await _albums
          .where('isApproved', isEqualTo: true)
          .limit(limit * 2)
          .get();
      final albums = snapshot.docs
          .map((doc) => AlbumDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.releaseYear.compareTo(a.releaseYear));
      debugPrint('[FIRESTORE] getFeaturedAlbums: got ${albums.length} albums');
      return albums.take(limit).toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getFeaturedAlbums ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Album>> getAlbumsByArtist(String artistId) async {
    try {
      debugPrint('[FIRESTORE] getAlbumsByArtist($artistId): fetching');
      // Two equality filters — works with auto single-field indexes.
      final snapshot = await _albums
          .where('artistId', isEqualTo: artistId)
          .where('isApproved', isEqualTo: true)
          .get();
      final albums = snapshot.docs
          .map((doc) => AlbumDto.fromFirestore(doc).toDomain())
          .toList()
        ..sort((a, b) => b.releaseYear.compareTo(a.releaseYear));
      debugPrint('[FIRESTORE] getAlbumsByArtist: got ${albums.length} albums');
      return albums;
    } catch (e, st) {
      debugPrint('[FIRESTORE] getAlbumsByArtist ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<Album?> getAlbumById(String id) async {
    try {
      debugPrint('[FIRESTORE] getAlbumById($id): fetching');
      final doc = await _albums.doc(id).get();
      if (!doc.exists) return null;
      return AlbumDto.fromFirestore(doc).toDomain();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getAlbumById ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Album>> getAlbumsByRegion(String region, {int limit = 20}) async {
    try {
      final snapshot = await _albums
          .where('region', isEqualTo: region)
          .where('isApproved', isEqualTo: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((doc) => AlbumDto.fromFirestore(doc).toDomain())
          .toList();
    } catch (e, st) {
      debugPrint('[FIRESTORE] getAlbumsByRegion ERROR: $e\n$st');
      rethrow;
    }
  }
}
