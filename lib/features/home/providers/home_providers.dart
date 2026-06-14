import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return ref.watch(songDatasourceProvider).getFeaturedSongs();
});

final trendingSongsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.watch(songDatasourceProvider).getTrendingSongs();
});

final newReleasesProvider = FutureProvider<List<Song>>((ref) async {
  return ref.watch(songDatasourceProvider).getNewReleases();
});

final featuredAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  return ref.watch(albumDatasourceProvider).getFeaturedAlbums();
});

final featuredArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  return ref.watch(artistDatasourceProvider).getFeaturedArtists();
});

final regionSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, region) async {
  return ref.watch(songDatasourceProvider).getSongsByRegion(region);
});

final albumDetailProvider =
    FutureProvider.family<Album?, String>((ref, albumId) async {
  return ref.watch(albumDatasourceProvider).getAlbumById(albumId);
});

final albumSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, albumId) async {
  return ref.watch(songDatasourceProvider).getSongsByAlbum(albumId);
});

final artistDetailProvider =
    FutureProvider.family<Artist?, String>((ref, artistId) async {
  return ref.watch(artistDatasourceProvider).getArtistById(artistId);
});

final artistSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, artistId) async {
  return ref.watch(songDatasourceProvider).getSongsByArtist(artistId);
});

final artistAlbumsProvider =
    FutureProvider.family<List<Album>, String>((ref, artistId) async {
  return ref.watch(albumDatasourceProvider).getAlbumsByArtist(artistId);
});

final favoriteSongsProvider = FutureProvider<List<Song>>((ref) async {
  final favoriteIds = ref.watch(favoritesProvider).toList();
  if (favoriteIds.isEmpty) return [];
  return ref.watch(songDatasourceProvider).getSongsByIds(favoriteIds);
});

final selectedRegionProvider = StateProvider<String>((ref) => 'All');
