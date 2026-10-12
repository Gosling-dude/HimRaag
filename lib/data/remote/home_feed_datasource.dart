import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import 'dto/album_dto.dart';
import 'dto/artist_dto.dart';
import 'dto/song_dto.dart';

/// The pre-built Home screen payload (`feeds/home`), written every 30 min by
/// the `aggregatePlays` Cloud Function. One document read replaces the
/// ~150–200 reads the individual Home queries cost.
class HomeFeed {
  const HomeFeed({
    required this.featuredSongs,
    required this.trendingSongs,
    required this.newReleases,
    required this.regionSongs,
    required this.albums,
    required this.artists,
    this.generatedAt,
  });

  /// Must match FEED_VERSION in backend/functions/src/logic/feed.ts. A newer
  /// server format is ignored (the app falls back to direct queries) rather
  /// than misread.
  static const int supportedVersion = 1;

  final List<Song> featuredSongs;
  final List<Song> trendingSongs;
  final List<Song> newReleases;
  final Map<String, List<Song>> regionSongs;
  final List<Album> albums;
  final List<Artist> artists;
  final DateTime? generatedAt;

  /// Parses the feed document; returns null for an unknown version or a
  /// malformed payload.
  static HomeFeed? fromMap(Map<String, dynamic> data) {
    if (data['version'] != supportedVersion) return null;
    final rawSongs = data['songs'];
    if (rawSongs is! Map) return null;

    final songs = <String, Song>{
      for (final e in rawSongs.entries)
        if (e.key is String && e.value is Map)
          e.key as String: SongDto.fromMap(
            e.key as String,
            Map<String, dynamic>.from(e.value as Map),
          ).toDomain(),
    };
    List<Song> pick(Object? ids) => [
          if (ids is List)
            for (final id in ids)
              if (songs[id] != null) songs[id]!,
        ];
    List<Map<String, dynamic>> maps(Object? raw) => [
          if (raw is List)
            for (final m in raw)
              if (m is Map && m['id'] is String) Map<String, dynamic>.from(m),
        ];

    final regionIds = data['regionSongIds'];
    final generatedAt = data['generatedAt'];
    return HomeFeed(
      featuredSongs: pick(data['featuredSongIds']),
      trendingSongs: pick(data['trendingSongIds']),
      newReleases: pick(data['newReleaseIds']),
      regionSongs: {
        if (regionIds is Map)
          for (final e in regionIds.entries)
            if (e.key is String) e.key as String: pick(e.value),
      },
      albums: [
        for (final m in maps(data['albums']))
          AlbumDto.fromMap(m['id'] as String, m).toDomain(),
      ],
      artists: [
        for (final m in maps(data['artists']))
          ArtistDto.fromMap(m['id'] as String, m).toDomain(),
      ],
      generatedAt: generatedAt is Timestamp ? generatedAt.toDate() : null,
    );
  }
}

class HomeFeedDatasource {
  HomeFeedDatasource(this._firestore);

  final FirebaseFirestore _firestore;

  /// The current feed, or null when it hasn't been generated yet (fresh
  /// project, functions not deployed) — callers then use direct queries.
  Future<HomeFeed?> fetch() async {
    final doc = await _firestore.collection('feeds').doc('home').get();
    final data = doc.data();
    if (data == null) {
      debugPrint('[FEED] feeds/home missing — using direct queries');
      return null;
    }
    final feed = HomeFeed.fromMap(data);
    debugPrint('[FEED] loaded version=${data['version']} '
        'usable=${feed != null} fromCache=${doc.metadata.isFromCache}');
    return feed;
  }
}
