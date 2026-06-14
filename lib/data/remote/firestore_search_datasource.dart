import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  // Unicode sentinel for Firestore prefix search.
  // Append  to the query string to match all strings starting with q.
  static const String _sentinel = '';

  Future<List<Song>> searchSongs(
    String query, {
    SearchFilters? filters,
    int page = 0,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      debugPrint('[SEARCH] searchSongs("$q"): fetching');
      // Range query on titleLowercase only — no compound where+range that needs
      // a composite index. Security rules allow all approved songs to be read.
      var ref = _firestore
          .collection(FirebaseConstants.songsCollection)
          .where('titleLowercase', isGreaterThanOrEqualTo: q)
          .where('titleLowercase', isLessThanOrEqualTo: '$q$_sentinel')
          .limit(_pageSize);

      final snapshot = await ref.get();
      var songs = snapshot.docs
          .map((doc) => SongDto.fromFirestore(doc).toDomain())
          .where((s) => s.isApproved)
          .toList();

      // Apply optional filters client-side to avoid additional composite indexes
      if (filters != null) {
        if (filters.region != null) {
          songs = songs.where((s) => s.region == filters.region).toList();
        }
        if (filters.genre != null) {
          songs = songs.where((s) => s.genre == filters.genre).toList();
        }
        if (filters.language != null) {
          songs = songs.where((s) => s.language == filters.language).toList();
        }
      }

      debugPrint('[SEARCH] searchSongs: found ${songs.length} results');
      return songs;
    } catch (e, st) {
      debugPrint('[SEARCH] searchSongs ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Artist>> searchArtists(String query, {int limit = 10}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      debugPrint('[SEARCH] searchArtists("$q"): fetching');
      final snapshot = await _firestore
          .collection(FirebaseConstants.artistsCollection)
          .where('nameLowercase', isGreaterThanOrEqualTo: q)
          .where('nameLowercase', isLessThanOrEqualTo: '$q$_sentinel')
          .limit(limit)
          .get();
      final artists = snapshot.docs
          .map((doc) => ArtistDto.fromFirestore(doc).toDomain())
          .toList();
      debugPrint('[SEARCH] searchArtists: found ${artists.length} results');
      return artists;
    } catch (e, st) {
      debugPrint('[SEARCH] searchArtists ERROR: $e\n$st');
      rethrow;
    }
  }

  Future<List<Album>> searchAlbums(String query, {int limit = 10}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    try {
      debugPrint('[SEARCH] searchAlbums("$q"): fetching');
      final snapshot = await _firestore
          .collection(FirebaseConstants.albumsCollection)
          .where('titleLowercase', isGreaterThanOrEqualTo: q)
          .where('titleLowercase', isLessThanOrEqualTo: '$q$_sentinel')
          .limit(limit)
          .get();
      final albums = snapshot.docs
          .map((doc) => AlbumDto.fromFirestore(doc).toDomain())
          .where((a) => a.isApproved)
          .toList();
      debugPrint('[SEARCH] searchAlbums: found ${albums.length} results');
      return albums;
    } catch (e, st) {
      debugPrint('[SEARCH] searchAlbums ERROR: $e\n$st');
      rethrow;
    }
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
