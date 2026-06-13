import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/firebase_constants.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import '../remote/dto/album_dto.dart';
import '../remote/dto/artist_dto.dart';
import '../remote/dto/song_dto.dart';
import '../remote/algolia_search_datasource.dart'
    show SearchFilters, SearchResult;

class FirestoreSearchDatasource {
  FirestoreSearchDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  static const int _pageSize = 30;

  Future<List<Song>> searchSongs(
    String query, {
    SearchFilters? filters,
    int page = 0,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    var ref = _firestore
        .collection(FirebaseConstants.songsCollection)
        .where(FirebaseConstants.songsIsApprovedField, isEqualTo: true)
        .where('titleLowercase', isGreaterThanOrEqualTo: q)
        .where('titleLowercase', isLessThanOrEqualTo: '$q')
        .limit(_pageSize);

    if (filters != null) {
      if (filters.region != null) {
        ref = ref.where(FirebaseConstants.songsRegionField,
            isEqualTo: filters.region);
      }
      if (filters.genre != null) {
        ref = ref.where(FirebaseConstants.songsGenreField,
            isEqualTo: filters.genre);
      }
      if (filters.language != null) {
        ref = ref.where(FirebaseConstants.songsLanguageField,
            isEqualTo: filters.language);
      }
    }

    final snapshot = await ref.get();
    return snapshot.docs
        .map((doc) => SongDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Artist>> searchArtists(String query, {int limit = 10}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snapshot = await _firestore
        .collection(FirebaseConstants.artistsCollection)
        .where('nameLowercase', isGreaterThanOrEqualTo: q)
        .where('nameLowercase', isLessThanOrEqualTo: '$q')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => ArtistDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snapshot = await _firestore
        .collection(FirebaseConstants.albumsCollection)
        .where('isApproved', isEqualTo: true)
        .where('titleLowercase', isGreaterThanOrEqualTo: q)
        .where('titleLowercase', isLessThanOrEqualTo: '$q')
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => AlbumDto.fromFirestore(doc).toDomain())
        .toList();
  }

  Future<SearchResult> search(String query, {SearchFilters? filters}) async {
    final results = await Future.wait([
      searchSongs(query, filters: filters),
      searchArtists(query),
      searchAlbums(query),
    ]);

    return SearchResult(
      songs: results[0] as List<Song>,
      artists: results[1] as List<Artist>,
      albums: results[2] as List<Album>,
      query: query,
    );
  }
}

final firestoreSearchProvider = Provider<FirestoreSearchDatasource>((ref) {
  return FirestoreSearchDatasource(FirebaseFirestore.instance);
});
