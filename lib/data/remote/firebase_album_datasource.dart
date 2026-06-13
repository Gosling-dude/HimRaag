import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';
import '../../domain/models/album.dart';
import 'dto/album_dto.dart';

class FirebaseAlbumDatasource {
  FirebaseAlbumDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _albums =>
      _firestore.collection(FirebaseConstants.albumsCollection);

  Future<List<Album>> getFeaturedAlbums({int limit = 10}) async {
    final snapshot = await _albums
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => AlbumDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Album>> getAlbumsByArtist(String artistId) async {
    final snapshot = await _albums
        .where('artistId', isEqualTo: artistId)
        .where('isApproved', isEqualTo: true)
        .orderBy('releaseYear', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => AlbumDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<Album?> getAlbumById(String id) async {
    final doc = await _albums.doc(id).get();
    if (!doc.exists) return null;
    return AlbumDto.fromFirestore(doc).toDomain();
  }

  Future<List<Album>> getAlbumsByRegion(String region, {int limit = 20}) async {
    final snapshot = await _albums
        .where('region', isEqualTo: region)
        .where('isApproved', isEqualTo: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => AlbumDto.fromFirestore(doc).toDomain())
        .toList();
  }
}
