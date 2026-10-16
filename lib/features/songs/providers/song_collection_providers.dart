import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/catalog_visibility.dart';
import '../../../data/remote/firebase_song_datasource.dart';
import '../../../data/services/audio_player_service.dart';
import '../../../domain/models/song.dart';
import '../../home/providers/home_providers.dart';

enum SongCollectionKind { featured, recommended, trending, newReleases, region }

/// A song collection behind a Home section: what its See All page lists and
/// what a queue started from it plays through.
///
/// Each collection starts from exactly the list its Home row shows (already
/// cached by the Home providers) and pages further approved songs from
/// Firestore on demand, so neither the page nor a queue stops at the songs
/// that were on screen.
@immutable
class SongCollection {
  const SongCollection._(this.kind, [this.region = '']);

  /// The Home banner's queue: featured songs first, then the rest of the
  /// eligible catalog. Also used to continue after "Continue Listening".
  static const featured = SongCollection._(SongCollectionKind.featured);
  static const recommended = SongCollection._(SongCollectionKind.recommended);
  static const trending = SongCollection._(SongCollectionKind.trending);
  static const newReleases = SongCollection._(SongCollectionKind.newReleases);

  const SongCollection.region(String region)
      : this._(SongCollectionKind.region, region);

  final SongCollectionKind kind;

  /// The region's value as stored on songs (e.g. `Garhwali`); empty for
  /// non-regional collections.
  final String region;

  static const _slugs = {
    SongCollectionKind.recommended: 'recommended',
    SongCollectionKind.trending: 'trending',
    SongCollectionKind.newReleases: 'new-releases',
  };

  /// The collection behind `/collection/<slug>`, or null for an unknown slug.
  static SongCollection? fromSlug(String slug) {
    for (final c in const [recommended, trending, newReleases]) {
      if (_slugs[c.kind] == slug) return c;
    }
    return null;
  }

  String get title => switch (kind) {
        SongCollectionKind.featured => 'Featured',
        SongCollectionKind.recommended => 'Made for You',
        SongCollectionKind.trending => 'Trending Now',
        SongCollectionKind.newReleases => 'New Releases',
        SongCollectionKind.region => '$region Songs',
      };

  /// Route of the collection's See All page.
  String get path => kind == SongCollectionKind.region
      ? '/region/${Uri.encodeComponent(region)}'
      : '/collection/${_slugs[kind] ?? kind.name}';

  /// Whether [song] belongs here: approved and — for a region — from exactly
  /// that region, so regional pages and queues never mix regions. Demo content
  /// is filtered separately by [SongVisibility.visibleToConsumers].
  bool accepts(Song song) =>
      song.isApproved &&
      (kind != SongCollectionKind.region || song.region == region);

  /// How songs fetched beyond the Home row are ordered within each page —
  /// the same ranking the collection's Home row uses.
  Comparator<Song>? get pageOrder => switch (kind) {
        SongCollectionKind.trending ||
        SongCollectionKind.region =>
          (a, b) => b.playCount.compareTo(a.playCount),
        SongCollectionKind.newReleases =>
          (a, b) => b.releaseYear.compareTo(a.releaseYear),
        _ => null,
      };

  @override
  bool operator ==(Object other) =>
      other is SongCollection && other.kind == kind && other.region == region;

  @override
  int get hashCode => Object.hash(kind, region);

  @override
  String toString() => 'SongCollection(${kind.name}${region.isEmpty ? '' : ':$region'})';
}

/// Further songs for a collection beyond its Home row.
abstract class SongPager {
  bool get hasMore;
  Future<List<Song>> nextPage();
}

/// Pages approved songs (optionally one region) from Firestore by document ID.
class FirestoreSongPager implements SongPager {
  FirestoreSongPager(this._datasource, {this.region, this.pageSize = 50});

  final FirebaseSongDatasource _datasource;
  final String? region;
  final int pageSize;

  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _hasMore = true;

  @override
  bool get hasMore => _hasMore;

  @override
  Future<List<Song>> nextPage() async {
    if (!_hasMore) return const [];
    final page = await _datasource.getApprovedSongsPageById(
      region: region,
      startAfter: _cursor,
      limit: pageSize,
    );
    _cursor = page.cursor ?? _cursor;
    _hasMore = page.songs.length >= pageSize;
    return page.songs;
  }
}

@immutable
class SongCollectionState {
  const SongCollectionState({
    this.songs = const [],
    this.isLoading = true,
    this.hasMore = false,
    this.error,
  });

  final List<Song> songs;

  /// True while the first list loads or another page is being fetched.
  final bool isLoading;
  final bool hasMore;
  final Object? error;

  SongCollectionState copyWith({
    List<Song>? songs,
    bool? isLoading,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) {
    return SongCollectionState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Holds one collection: the Home row's list first, then remote pages
/// appended (never re-sorted, so list positions — and queues built from them —
/// stay stable), de-duplicated by song id.
class SongCollectionController extends StateNotifier<SongCollectionState> {
  SongCollectionController(
    this.collection, {
    required Future<List<Song>> seed,
    SongPager? pager,
  })  : _pager = pager,
        super(const SongCollectionState()) {
    _initializing = _init(seed);
  }

  /// Upper bound on remote pages read by one [loadMore] while skipping songs
  /// the collection already has, so a misbehaving cursor can't loop forever.
  static const int maxPagesPerLoad = 20;

  final SongCollection collection;
  final SongPager? _pager;
  final Set<String> _ids = {};
  Future<void>? _initializing;
  Future<void>? _paging;

  List<Song> get songs => state.songs;

  /// Whether [loadMore] may still add songs (including while the initial list
  /// is loading).
  bool get canLoadMore => _initializing != null || state.hasMore;

  List<Song> _eligible(List<Song> songs) => songs
      .visibleToConsumers()
      .where(collection.accepts)
      .where((s) => _ids.add(s.id))
      .toList();

  Future<void> _init(Future<List<Song>> seed) async {
    try {
      final songs = _eligible(await seed);
      if (!mounted) return;
      state = SongCollectionState(
        songs: songs,
        isLoading: false,
        hasMore: _pager?.hasMore ?? false,
      );
    } catch (e, st) {
      debugPrint('[COLLECTION] $collection failed to load: $e\n$st');
      if (!mounted) return;
      state = SongCollectionState(isLoading: false, error: e);
    } finally {
      _initializing = null;
    }
  }

  /// Fetches the next page; concurrent callers (the list scrolling and the
  /// player extending its queue) share one request.
  Future<void> loadMore() =>
      _paging ??= _loadMore().whenComplete(() => _paging = null);

  Future<void> _loadMore() async {
    // The Home row's songs must land first so their ids de-duplicate pages.
    await _initializing;
    final pager = _pager;
    if (pager == null || !state.hasMore || !mounted) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final fresh = <Song>[];
      // The bundled catalog is already in the Home row, so a remote page can
      // hold nothing new; keep going until something is, or the collection
      // runs out, instead of reporting a false end.
      for (var i = 0;
          i < maxPagesPerLoad && fresh.isEmpty && pager.hasMore;
          i++) {
        final page = _eligible(await pager.nextPage());
        final order = collection.pageOrder;
        if (order != null) page.sort(order);
        fresh.addAll(page);
      }
      if (!mounted) return;
      state = state.copyWith(
        songs: [...state.songs, ...fresh],
        isLoading: false,
        hasMore: pager.hasMore,
      );
    } catch (e, st) {
      debugPrint('[COLLECTION] $collection page failed (keeping loaded '
          'songs): $e\n$st');
      if (!mounted) return;
      // Keep what we have; the list offers a retry and the player tries again
      // on its next track change.
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}

/// The cached Home list each collection starts from.
FutureProvider<List<Song>> songCollectionSeedProvider(SongCollection c) {
  return switch (c.kind) {
    SongCollectionKind.featured => featuredSongsProvider,
    SongCollectionKind.recommended => personalizedSongsProvider,
    SongCollectionKind.trending => trendingSongsProvider,
    SongCollectionKind.newReleases => newReleasesProvider,
    SongCollectionKind.region => regionSongsProvider(c.region),
  };
}

typedef SongPagerFactory = SongPager? Function(SongCollection collection);

/// Creates the remote pager for a collection — `null` for Made for You, which
/// ranks a fixed pool (the bundled catalog + Trending) by design.
final songPagerFactoryProvider = Provider<SongPagerFactory>((ref) {
  final datasource = ref.watch(songDatasourceProvider);
  return (collection) => switch (collection.kind) {
        SongCollectionKind.recommended => null,
        SongCollectionKind.region =>
          FirestoreSongPager(datasource, region: collection.region),
        _ => FirestoreSongPager(datasource),
      };
});

/// Not auto-disposed: a See All list keeps its loaded pages when revisited,
/// and a queue started from it keeps growing after the page is closed.
final songCollectionProvider = StateNotifierProvider.family<
    SongCollectionController, SongCollectionState, SongCollection>(
  (ref, collection) {
    // Watching the seed's future rebuilds the collection after a Home refresh.
    final seed = ref.watch(songCollectionSeedProvider(collection).future);
    return SongCollectionController(
      collection,
      seed: seed,
      pager: ref.watch(songPagerFactoryProvider)(collection),
    );
  },
);

/// Lets the player grow a queue from a collection. It reads the live
/// controller on every call, so a collection rebuilt by a Home refresh keeps
/// feeding a queue that started before the refresh.
final songCollectionQueueSourceProvider =
    Provider.family<QueueSource, SongCollection>(
  (ref, collection) => _CollectionQueueSource(ref, collection),
);

class _CollectionQueueSource implements QueueSource {
  _CollectionQueueSource(this._ref, this._collection);

  final Ref _ref;
  final SongCollection _collection;

  SongCollectionController get _controller =>
      _ref.read(songCollectionProvider(_collection).notifier);

  @override
  List<Song> get songs => _controller.songs;

  @override
  bool get hasMore => _controller.canLoadMore;

  @override
  Future<List<Song>> loadMore() async {
    final controller = _controller;
    await controller.loadMore();
    return controller.songs;
  }
}
