import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local/hive_boxes.dart';
import '../../../data/local/models/hive_recently_played.dart';
import '../../../data/services/download_service.dart';
import '../../../domain/models/song.dart';

final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier();
});

final isFavoriteProvider = Provider.family<bool, String>((ref, songId) {
  return ref.watch(favoritesProvider).contains(songId);
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  FavoritesNotifier() : super({}) {
    _load();
  }

  void _load() {
    state = HiveBoxes.favorites.values.toSet();
  }

  Future<void> toggleFavorite(String songId) async {
    if (state.contains(songId)) {
      await HiveBoxes.favorites.delete(songId);
      state = state.difference({songId});
    } else {
      await HiveBoxes.favorites.put(songId, songId);
      state = {...state, songId};
    }
  }

  bool isFavorite(String songId) => state.contains(songId);
}

final libraryProvider =
    StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier(ref);
});

class LibraryState {
  const LibraryState({
    this.favorites = const [],
    this.downloads = const [],
    this.recentlyPlayed = const [],
  });

  final List<String> favorites;
  final List<Song> downloads;
  final List<Song> recentlyPlayed;
}

class LibraryNotifier extends StateNotifier<LibraryState> {
  LibraryNotifier(this._ref) : super(const LibraryState()) {
    _load();
  }

  final Ref _ref;

  void _load() {
    final downloads =
        _ref.read(downloadServiceProvider).getAllDownloadedSongs();
    final recent = _loadRecentlyPlayed();
    state = LibraryState(
      favorites: HiveBoxes.favorites.values.toList(),
      downloads: downloads,
      recentlyPlayed: recent,
    );
  }

  List<Song> _loadRecentlyPlayed() {
    final items = HiveBoxes.recentlyPlayed.values.toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return items
        .take(50)
        .map((h) => Song(
              id: h.songId,
              title: h.songTitle,
              artistId: '',
              artistName: h.artistName,
              albumId: '',
              albumTitle: '',
              audioUrl: h.audioUrl ?? '',
              artworkUrl: h.artworkUrl,
              duration: Duration.zero,
              region: '',
              language: '',
              genre: '',
              releaseYear: 0,
              playCount: 0,
              tags: const [],
              isApproved: true,
              isDownloadable: false,
              localPath: h.localPath,
            ))
        .toList();
  }

  Future<void> toggleFavorite(String songId) async {
    await _ref.read(favoritesProvider.notifier).toggleFavorite(songId);
    state = LibraryState(
      favorites: HiveBoxes.favorites.values.toList(),
      downloads: state.downloads,
      recentlyPlayed: state.recentlyPlayed,
    );
  }

  void refreshDownloads() {
    final downloads =
        _ref.read(downloadServiceProvider).getAllDownloadedSongs();
    state = LibraryState(
      favorites: state.favorites,
      downloads: downloads,
      recentlyPlayed: state.recentlyPlayed,
    );
  }
}

final recentlyPlayedProvider =
    StateNotifierProvider<RecentlyPlayedNotifier, List<Song>>((ref) {
  return RecentlyPlayedNotifier();
});

class RecentlyPlayedNotifier extends StateNotifier<List<Song>> {
  RecentlyPlayedNotifier() : super([]) {
    _load();
  }

  void _load() {
    final items = HiveBoxes.recentlyPlayed.values.toList()
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    state = items
        .take(50)
        .map((h) => Song(
              id: h.songId,
              title: h.songTitle,
              artistId: '',
              artistName: h.artistName,
              albumId: '',
              albumTitle: '',
              audioUrl: h.audioUrl ?? '',
              artworkUrl: h.artworkUrl,
              duration: Duration.zero,
              region: '',
              language: '',
              genre: '',
              releaseYear: 0,
              playCount: 0,
              tags: const [],
              isApproved: true,
              isDownloadable: false,
              localPath: h.localPath,
            ))
        .toList();
  }

  Future<void> addSong(Song song) async {
    await HiveBoxes.recentlyPlayed.delete(song.id);
    await HiveBoxes.recentlyPlayed.put(
      song.id,
      HiveRecentlyPlayed(
        songId: song.id,
        songTitle: song.title,
        artistName: song.artistName,
        artworkUrl: song.artworkUrl,
        playedAt: DateTime.now(),
        audioUrl: song.audioUrl,
        localPath: song.localPath,
      ),
    );
    _load();
  }

  void clearAll() {
    HiveBoxes.recentlyPlayed.clear();
    state = [];
  }
}

final downloadedSongsProvider = Provider<List<Song>>((ref) {
  return ref.watch(downloadServiceProvider).getAllDownloadedSongs();
});
