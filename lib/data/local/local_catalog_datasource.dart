import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/content_constants.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';

/// Loads the locally-imported catalog bundled at
/// `assets/catalog/imported_catalog.json` (produced by
/// `scripts/generate_import_catalog.js`).
///
/// This is the runtime source for imported audio so the songs reach
/// Home/Search/Album/Artist **without** a Firestore write. Audio plays via the
/// `asset:///assets/audio/...` URLs already on each record. Parsing is cached;
/// a missing/invalid asset degrades gracefully to empty lists.
class LocalCatalogDatasource {
  LocalCatalogDatasource();

  static const String _assetPath = 'assets/catalog/imported_catalog.json';

  Future<_Catalog>? _cache;

  Future<_Catalog> _load() {
    return _cache ??= _parse();
  }

  Future<_Catalog> _parse() async {
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final songs = (map['songs'] as List? ?? [])
          .map((e) => _song(Map<String, dynamic>.from(e as Map)))
          .toList();
      final albums = (map['albums'] as List? ?? [])
          .map((e) => _album(Map<String, dynamic>.from(e as Map)))
          .toList();
      final artists = (map['artists'] as List? ?? [])
          .map((e) => _artist(Map<String, dynamic>.from(e as Map)))
          .toList();
      debugPrint('[LOCAL_CATALOG] loaded songs=${songs.length} '
          'albums=${albums.length} artists=${artists.length}');
      return _Catalog(songs: songs, albums: albums, artists: artists);
    } catch (e, st) {
      debugPrint('[LOCAL_CATALOG] load failed (treating as empty): $e\n$st');
      return const _Catalog(songs: [], albums: [], artists: []);
    }
  }

  Future<List<Song>> songs() async => (await _load()).songs;
  Future<List<Album>> albums() async => (await _load()).albums;
  Future<List<Artist>> artists() async => (await _load()).artists;

  Future<List<Song>> songsForAlbum(String albumId) async =>
      (await songs()).where((s) => s.albumId == albumId).toList();

  Future<List<Song>> songsForArtist(String artistId) async =>
      (await songs()).where((s) => s.artistId == artistId).toList();

  Future<List<Album>> albumsForArtist(String artistId) async =>
      (await albums()).where((a) => a.artistId == artistId).toList();

  Future<Album?> albumById(String id) async {
    for (final a in await albums()) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<Artist?> artistById(String id) async {
    for (final a in await artists()) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Case-insensitive `contains` over title / artist / album.
  Future<({List<Song> songs, List<Album> albums, List<Artist> artists})>
      search(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return (songs: <Song>[], albums: <Album>[], artists: <Artist>[]);
    }
    final c = await _load();
    return (
      songs: c.songs
          .where((s) =>
              s.title.toLowerCase().contains(q) ||
              s.artistName.toLowerCase().contains(q) ||
              s.albumTitle.toLowerCase().contains(q))
          .toList(),
      albums: c.albums
          .where((a) =>
              a.title.toLowerCase().contains(q) ||
              a.artistName.toLowerCase().contains(q))
          .toList(),
      artists:
          c.artists.where((a) => a.name.toLowerCase().contains(q)).toList(),
    );
  }

  // ── JSON → domain mapping ──────────────────────────────────────────────────

  static Song _song(Map<String, dynamic> m) {
    final status = ApprovalStatus.fromWire(m['approvalStatus'] as String?);
    return Song(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      artistId: m['artistId'] as String? ?? '',
      artistName: m['artistName'] as String? ?? '',
      albumId: m['albumId'] as String? ?? '',
      albumTitle: m['albumTitle'] as String? ?? '',
      audioUrl: m['audioUrl'] as String? ?? '',
      artworkUrl: m['artworkUrl'] as String? ?? '',
      duration: Duration(milliseconds: (m['durationMs'] as num? ?? 0).toInt()),
      region: m['region'] as String? ?? '',
      language: m['language'] as String? ?? '',
      genre: m['genre'] as String? ?? '',
      releaseYear: (m['releaseYear'] as num? ?? 0).toInt(),
      playCount: (m['playCount'] as num? ?? 0).toInt(),
      tags: (m['tags'] as List? ?? []).map((e) => e.toString()).toList(),
      isApproved: status.isApproved,
      isDownloadable: m['isDownloadable'] != false,
      lyrics: m['lyrics'] as String?,
      mood: m['mood'] as String?,
      slug: m['slug'] as String? ?? '',
      license: LicenseType.fromWire(m['license'] as String?),
      attribution: m['attribution'] as String? ?? '',
      licenseUrl: m['licenseUrl'] as String?,
      sourceUrl: m['sourceUrl'] as String?,
      approvalStatus: status,
      isPublished: m['isPublished'] == true,
      rightsCleared: m['rightsCleared'] == true,
    );
  }

  static Album _album(Map<String, dynamic> m) {
    final status = ApprovalStatus.fromWire(m['approvalStatus'] as String?);
    return Album(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      artistId: m['artistId'] as String? ?? '',
      artistName: m['artistName'] as String? ?? '',
      artworkUrl: m['artworkUrl'] as String? ?? '',
      region: m['region'] as String? ?? '',
      language: m['language'] as String? ?? '',
      genre: m['genre'] as String? ?? '',
      releaseYear: (m['releaseYear'] as num? ?? 0).toInt(),
      songCount: (m['songCount'] as num? ?? 0).toInt(),
      totalDuration:
          Duration(milliseconds: (m['totalDurationMs'] as num? ?? 0).toInt()),
      description: m['description'] as String?,
      tags: (m['tags'] as List? ?? []).map((e) => e.toString()).toList(),
      isApproved: status.isApproved,
      slug: m['slug'] as String? ?? '',
      license: LicenseType.fromWire(m['license'] as String?),
      attribution: m['attribution'] as String? ?? '',
      approvalStatus: status,
      isPublished: m['isPublished'] == true,
      rightsCleared: m['rightsCleared'] == true,
    );
  }

  static Artist _artist(Map<String, dynamic> m) {
    final status = ApprovalStatus.fromWire(m['approvalStatus'] as String?);
    return Artist(
      id: m['id'] as String,
      name: m['name'] as String? ?? '',
      imageUrl: m['imageUrl'] as String? ?? '',
      region: m['region'] as String? ?? '',
      bio: m['bio'] as String? ?? '',
      songCount: (m['songCount'] as num? ?? 0).toInt(),
      albumCount: (m['albumCount'] as num? ?? 0).toInt(),
      genres: (m['genres'] as List? ?? []).map((e) => e.toString()).toList(),
      monthlyListeners: (m['monthlyListeners'] as num? ?? 0).toInt(),
      isVerified: m['isVerified'] == true,
      slug: m['slug'] as String? ?? '',
      approvalStatus: status,
      isPublished: m['isPublished'] == true,
      rightsNote: m['rightsNote'] as String? ?? '',
    );
  }
}

class _Catalog {
  const _Catalog({
    required this.songs,
    required this.albums,
    required this.artists,
  });
  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;
}

/// Single shared instance (parsing is cached inside).
final localCatalogProvider =
    Provider<LocalCatalogDatasource>((ref) => LocalCatalogDatasource());

final localSongsProvider =
    FutureProvider<List<Song>>((ref) => ref.watch(localCatalogProvider).songs());
final localAlbumsProvider = FutureProvider<List<Album>>(
    (ref) => ref.watch(localCatalogProvider).albums());
final localArtistsProvider = FutureProvider<List<Artist>>(
    (ref) => ref.watch(localCatalogProvider).artists());
