import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants/firebase_constants.dart';
import '../../domain/models/artist.dart';
import 'dto/artist_dto.dart';

class FirebaseArtistDatasource {
  FirebaseArtistDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _artists =>
      _firestore.collection(FirebaseConstants.artistsCollection);

  Future<List<Artist>> getFeaturedArtists({int limit = 10}) async {
    final snapshot = await _artists
        .where('isVerified', isEqualTo: true)
        .orderBy('monthlyListeners', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => ArtistDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<Artist?> getArtistById(String id) async {
    final doc = await _artists.doc(id).get();
    if (!doc.exists) return null;
    return ArtistDto.fromFirestore(doc).toDomain();
  }

  Future<List<Artist>> getArtistsByRegion(String region,
      {int limit = 20}) async {
    final snapshot =
        await _artists.where('region', isEqualTo: region).limit(limit).get();
    return snapshot.docs
        .map((doc) => ArtistDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Artist>> getArtistsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final futures = ids.map((id) => _artists.doc(id).get()).toList();
    final snapshots = await Future.wait(futures);
    return snapshots
        .where((doc) => doc.exists)
        .map((doc) => ArtistDto.fromFirestore(doc).toDomain())
        .toList();
  }
}
