import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/catalog_visibility.dart';
import '../../../data/remote/firebase_album_datasource.dart';
import '../../../data/remote/firebase_artist_datasource.dart';
import '../../../data/remote/firebase_song_datasource.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/song.dart';
import '../../library/providers/library_providers.dart';

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
  return songs.visibleToConsumers();
});

final trendingSongsProvider = FutureProvider<List<Song>>((ref) async {
  final songs = await ref.watch(songDatasourceProvider).getTrendingSongs();
  return songs.visibleToConsumers();
});

final newReleasesProvider = FutureProvider<List<Song>>((ref) async {
  final songs = await ref.watch(songDatasourceProvider).getNewReleases();
  return songs.visibleToConsumers();
});

final featuredAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final albums = await ref.watch(albumDatasourceProvider).getFeaturedAlbums();
  return albums.visibleToConsumers();
});

final featuredArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final artists = await ref.watch(artistDatasourceProvider).getFeaturedArtists();
  return artists.visibleToConsumers();
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
