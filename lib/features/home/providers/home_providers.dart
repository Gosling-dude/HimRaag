import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../data/catalog_visibility.dart';
import '../../../data/remote/firebase_album_datasource.dart';
import '../../../data/remote/firebase_artist_datasource.dart';
import '../../../data/remote/firebase_song_datasource.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/song.dart';
import '../../library/providers/library_providers.dart';

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

final featuredSongsProvider = FutureProvider<List<Song>>((ref) async {
  final songs = await ref.watch(songDatasourceProvider).getFeaturedSongs();
  return _logVisibility('featuredSongs', songs, songs.visibleToConsumers());
});

final trendingSongsProvider = FutureProvider<List<Song>>((ref) async {
  final songs = await ref.watch(songDatasourceProvider).getTrendingSongs();
  return _logVisibility('trendingSongs', songs, songs.visibleToConsumers());
});

final newReleasesProvider = FutureProvider<List<Song>>((ref) async {
  final songs = await ref.watch(songDatasourceProvider).getNewReleases();
  return _logVisibility('newReleases', songs, songs.visibleToConsumers());
});

final featuredAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final albums = await ref.watch(albumDatasourceProvider).getFeaturedAlbums();
  return _logVisibility('featuredAlbums', albums, albums.visibleToConsumers());
});

final featuredArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final artists = await ref.watch(artistDatasourceProvider).getFeaturedArtists();
  return _logVisibility(
      'featuredArtists', artists, artists.visibleToConsumers());
});

final regionSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, region) async {
  final songs = await ref.watch(songDatasourceProvider).getSongsByRegion(region);
  return songs.visibleToConsumers();
});

final albumDetailProvider =
    FutureProvider.family<Album?, String>((ref, albumId) async {
  return ref.watch(albumDatasourceProvider).getAlbumById(albumId);
});

final albumSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, albumId) async {
  final songs = await ref.watch(songDatasourceProvider).getSongsByAlbum(albumId);
  return songs.visibleToConsumers();
});

final artistDetailProvider =
    FutureProvider.family<Artist?, String>((ref, artistId) async {
  return ref.watch(artistDatasourceProvider).getArtistById(artistId);
});

final artistSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, artistId) async {
  final songs = await ref.watch(songDatasourceProvider).getSongsByArtist(artistId);
  return songs.visibleToConsumers();
});

final artistAlbumsProvider =
    FutureProvider.family<List<Album>, String>((ref, artistId) async {
  final albums = await ref.watch(albumDatasourceProvider).getAlbumsByArtist(artistId);
  return albums.visibleToConsumers();
});

final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  final favoriteIds = ref.watch(favoritesProvider).toList();
  if (favoriteIds.isEmpty) return [];
  final songs = await ref.watch(songDatasourceProvider).getSongsByIds(favoriteIds);
  return songs.visibleToConsumers();
});

final selectedRegionProvider = StateProvider<String>((ref) => 'All');
