import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/display/consumer_labels.dart';
import '../../../data/catalog_visibility.dart';
import '../../../data/local/local_catalog_datasource.dart';
import '../../../domain/models/song.dart';
import '../../home/providers/home_providers.dart';

/// Immutable state for the paginated "All Songs" feed.
@immutable
class AllSongsState {
  const AllSongsState({
    this.songs = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  final List<Song> songs;
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  AllSongsState copyWith({
    List<Song>? songs,
    bool? isLoading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return AllSongsState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Loads every approved song, paginated from Firestore (cursor by title) and
/// seeded offline-first from the bundled catalog. Scales to 100k+ songs: each
/// page is a bounded, indexed query — never a full-collection scan.
class AllSongsController extends StateNotifier<AllSongsState> {
  AllSongsController(this._ref) : super(const AllSongsState()) {
    _init();
  }

  final Ref _ref;
  static const int pageSize = 60;
  final Set<String> _seen = <String>{};
  String? _cursor;
  bool _busy = false;

  void _sort(List<Song> list) =>
      list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  Future<void> _init() async {
    // Offline-first: surface the bundled catalog immediately, then page Firestore.
    try {
      final local =
          (await _ref.read(localSongsProvider.future)).visibleToConsumers();
      for (final s in local) {
        _seen.add(s.id);
      }
      final seeded = [...local];
      _sort(seeded);
      state = state.copyWith(songs: seeded);
    } catch (e) {
      debugPrint('[ALL_SONGS] local seed failed: $e');
    }
    await loadMore();
  }

  Future<void> loadMore() async {
    if (_busy || !state.hasMore) return;
    _busy = true;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _ref
          .read(songDatasourceProvider)
          .getApprovedSongsPage(limit: pageSize, startAfterTitle: _cursor);
      if (page.isNotEmpty) _cursor = page.last.title;
      final fresh =
          page.visibleToConsumers().where((s) => _seen.add(s.id)).toList();
      final merged = [...state.songs, ...fresh];
      _sort(merged);
      state = state.copyWith(
        songs: merged,
        isLoading: false,
        hasMore: page.length >= pageSize,
      );
    } catch (e, st) {
      debugPrint('[ALL_SONGS] page load failed (keeping local): $e\n$st');
      // Offline / index missing: stop paging but keep whatever we have.
      state = state.copyWith(isLoading: false, hasMore: false, error: e);
    } finally {
      _busy = false;
    }
  }

  Future<void> refresh() async {
    _seen.clear();
    _cursor = null;
    state = const AllSongsState();
    await _init();
  }
}

final allSongsControllerProvider =
    StateNotifierProvider<AllSongsController, AllSongsState>(
        (ref) => AllSongsController(ref));

// ── Filters ───────────────────────────────────────────────────────────────────

final allSongsQueryProvider = StateProvider<String>((ref) => '');
final allSongsRegionProvider = StateProvider<String>((ref) => 'All');
final allSongsArtistProvider = StateProvider<String>((ref) => 'All');

/// Distinct artist display-names across the loaded songs (for the artist filter).
final allSongsArtistOptionsProvider = Provider<List<String>>((ref) {
  final songs = ref.watch(allSongsControllerProvider).songs;
  final names = <String>{for (final s in songs) s.displayArtist};
  final list = names.where((n) => n.trim().isNotEmpty).toList()..sort();
  return list;
});

/// Distinct regions across the loaded songs (for the region filter).
final allSongsRegionOptionsProvider = Provider<List<String>>((ref) {
  final songs = ref.watch(allSongsControllerProvider).songs;
  final regions = <String>{
    for (final s in songs)
      if (s.displayRegion.trim().isNotEmpty) s.displayRegion,
  };
  final list = regions.toList()..sort();
  return list;
});

/// Songs after applying the search query + region + artist filters.
final filteredAllSongsProvider = Provider<List<Song>>((ref) {
  final all = ref.watch(allSongsControllerProvider).songs;
  final q = ref.watch(allSongsQueryProvider).trim().toLowerCase();
  final region = ref.watch(allSongsRegionProvider);
  final artist = ref.watch(allSongsArtistProvider);

  return all.where((s) {
    if (region != 'All' && s.displayRegion != region) return false;
    if (artist != 'All' && s.displayArtist != artist) return false;
    if (q.isNotEmpty) {
      final hay =
          '${s.title} ${s.displayArtist} ${s.albumTitle} ${s.displayRegion}'
              .toLowerCase();
      if (!hay.contains(q)) return false;
    }
    return true;
  }).toList();
});
