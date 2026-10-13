import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/catalog_visibility.dart';
import '../../../data/local/local_catalog_datasource.dart';
import '../../../data/remote/firebase_album_datasource.dart';
import '../../../data/remote/firebase_artist_datasource.dart';
import '../../../data/remote/firebase_song_datasource.dart';
import '../../../data/remote/home_feed_datasource.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/song.dart';
import '../../library/providers/library_providers.dart';

/// Union of [local] (imported) + [remote] (Firestore) items, de-duplicated by
/// id with local taking precedence and appearing first (imported songs have
/// playCount 0 and would otherwise sort to the bottom of Home rows).
List<T> _mergeById<T>(List<T> local, List<T> remote, String Function(T) id) {
  final seen = <String>{};
  final out = <T>[];
  for (final item in [...local, ...remote]) {
    if (seen.add(id(item))) out.add(item);
  }
  return out;
}

/// Diagnostics: logs how many records the datasource returned vs how many
/// survive the consumer visibility filter, plus the demo-content flag. In a
/// release build `includeDemoContent` is false, so an all-DEMO_ONLY catalog
/// filters to zero here — this is where catalog counts drop to empty.
List<T> _logVisibility<T>(String label, List<T> loaded, List<T> visible) {
  debugPrint('[CATALOG] $label loaded=${loaded.length} '
      'visible=${visible.length} '
      'includeDemoContent=${AppConfig.includeDemoContent}');
  return visible;
}

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final songDatasourceProvider = Provider<FirebaseSongDatasource>((ref) {
  return FirebaseSongDatasource(ref.watch(firestoreProvider));
});

final albumDatasourceProvider = Provider<FirebaseAlbumDatasource>((ref) {
  return FirebaseAlbumDatasource(ref.watch(firestoreProvider));
});

final artistDatasourceProvider = Provider<FirebaseArtistDatasource>((ref) {
  return FirebaseArtistDatasource(ref.watch(firestoreProvider));
});

final homeFeedDatasourceProvider = Provider<HomeFeedDatasource>((ref) {
  return HomeFeedDatasource(ref.watch(firestoreProvider));
});

/// The server-built Home payload, or null → rows fall back to their own
/// Firestore queries (e.g. before the Cloud Functions are deployed).
final homeFeedProvider = FutureProvider<HomeFeed?>((ref) async {
  try {
    return await ref.watch(homeFeedDatasourceProvider).fetch();
  } catch (e) {
    debugPrint('[FEED] fetch failed, using direct queries: $e');
    return null;
  }
});

/// Top [limit] consumer-visible items from the feed. The server over-fetches
/// so demo-only entries filtered out in release builds don't empty a row.
List<Song> _topSongs(List<Song> songs, int limit) =>
    songs.visibleToConsumers().take(limit).toList();

final featuredSongsProvider = FutureProvider<List<Song>>((ref) async {
  final feed = await ref.watch(homeFeedProvider.future);
  final remote = feed != null
      ? _topSongs(feed.featuredSongs, 10)
      : await ref.watch(songDatasourceProvider).getFeaturedSongs();
  final local = await ref.watch(localSongsProvider.future);
  final merged = _mergeById(local, remote, (s) => s.id);
  return _logVisibility('featuredSongs', merged, merged.visibleToConsumers());
});

final trendingSongsProvider = FutureProvider<List<Song>>((ref) async {
  final feed = await ref.watch(homeFeedProvider.future);
  final remote = feed != null
      ? _topSongs(feed.trendingSongs, 20)
      : await ref.watch(songDatasourceProvider).getTrendingSongs();
  final local = await ref.watch(localSongsProvider.future);
  final merged = _mergeById(local, remote, (s) => s.id);
  return _logVisibility('trendingSongs', merged, merged.visibleToConsumers());
});

final newReleasesProvider = FutureProvider<List<Song>>((ref) async {
  final feed = await ref.watch(homeFeedProvider.future);
  final remote = feed != null
      ? _topSongs(feed.newReleases, 20)
      : await ref.watch(songDatasourceProvider).getNewReleases();
  final local = await ref.watch(localSongsProvider.future);
  final merged = _mergeById(local, remote, (s) => s.id);
  return _logVisibility('newReleases', merged, merged.visibleToConsumers());
});

final featuredAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final feed = await ref.watch(homeFeedProvider.future);
  final remote = feed != null
      ? feed.albums.visibleToConsumers().take(10).toList()
      : await ref.watch(albumDatasourceProvider).getFeaturedAlbums();
  final local = await ref.watch(localAlbumsProvider.future);
  final merged = _mergeById(local, remote, (a) => a.id);
  return _logVisibility('featuredAlbums', merged, merged.visibleToConsumers());
});

final featuredArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final feed = await ref.watch(homeFeedProvider.future);
  final remote = feed != null
      ? feed.artists.visibleToConsumers().take(10).toList()
      : await ref.watch(artistDatasourceProvider).getFeaturedArtists();
  final local = await ref.watch(localArtistsProvider.future);
  final merged = _mergeById(local, remote, (a) => a.id);
  return _logVisibility(
      'featuredArtists', merged, merged.visibleToConsumers());
});

final regionSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, region) async {
  final remote = await ref.watch(songDatasourceProvider).getSongsByRegion(region);
  final local = (await ref.watch(localSongsProvider.future))
      .where((s) => s.region == region)
      .toList();
  return _mergeById(local, remote, (s) => s.id).visibleToConsumers();
});

/// Home's "<Region> Hits" rows: served from the feed when available. The
/// Region screen keeps using [regionSongsProvider] for its fuller list.
final homeRegionSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, region) async {
  final feed = await ref.watch(homeFeedProvider.future);
  if (feed == null) return ref.watch(regionSongsProvider(region).future);
  final local = (await ref.watch(localSongsProvider.future))
      .where((s) => s.region == region)
      .toList();
  final remote = feed.regionSongs[region] ?? const <Song>[];
  return _mergeById(local, remote, (s) => s.id).visibleToConsumers();
});

/// Regions that actually have at least one visible song, in catalog order.
/// Drives the curated "<Region> Hits" rows on Home — empty regions never
/// render, so there are no blank sections.
final populatedRegionsProvider = FutureProvider<List<String>>((ref) async {
  final local = await ref.watch(localSongsProvider.future);
  final remote = await ref.watch(trendingSongsProvider.future);
  final feed = await ref.watch(homeFeedProvider.future);
  final present = {
    for (final s in [...local, ...remote])
      if (s.region.trim().isNotEmpty && s.region != 'Needs Review') s.region,
    for (final e in feed?.regionSongs.entries ?? <MapEntry<String, List<Song>>>[])
      if (e.value.visibleToConsumers().isNotEmpty) e.key,
  };
  return AppConstants.pahadiRegions.where(present.contains).toList();
});

final albumDetailProvider =
    FutureProvider.family<Album?, String>((ref, albumId) async {
  final remote = await ref.watch(albumDatasourceProvider).getAlbumById(albumId);
  if (remote != null) return remote;
  return ref.watch(localCatalogProvider).albumById(albumId);
});

final albumSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, albumId) async {
  final remote =
      await ref.watch(songDatasourceProvider).getSongsByAlbum(albumId);
  final local = await ref.watch(localCatalogProvider).songsForAlbum(albumId);
  return _mergeById(local, remote, (s) => s.id).visibleToConsumers();
});

final artistDetailProvider =
    FutureProvider.family<Artist?, String>((ref, artistId) async {
  final remote =
      await ref.watch(artistDatasourceProvider).getArtistById(artistId);
  if (remote != null) return remote;
  return ref.watch(localCatalogProvider).artistById(artistId);
});

final artistSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, artistId) async {
  final remote =
      await ref.watch(songDatasourceProvider).getSongsByArtist(artistId);
  final local = await ref.watch(localCatalogProvider).songsForArtist(artistId);
  return _mergeById(local, remote, (s) => s.id).visibleToConsumers();
});

final artistAlbumsProvider =
    FutureProvider.family<List<Album>, String>((ref, artistId) async {
  final remote =
      await ref.watch(albumDatasourceProvider).getAlbumsByArtist(artistId);
  final local = await ref.watch(localCatalogProvider).albumsForArtist(artistId);
  return _mergeById(local, remote, (a) => a.id).visibleToConsumers();
});

final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  final favoriteIds = ref.watch(favoritesProvider).toList();
  if (favoriteIds.isEmpty) return [];
  final songs = await ref.watch(songDatasourceProvider).getSongsByIds(favoriteIds);
  return songs.visibleToConsumers();
});

final selectedRegionProvider = StateProvider<String>((ref) => 'All');
