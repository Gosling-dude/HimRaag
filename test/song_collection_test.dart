import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himraag/data/local/local_catalog_datasource.dart';
import 'package:himraag/data/remote/firebase_song_datasource.dart';
import 'package:himraag/domain/models/song.dart';
import 'package:himraag/domain/models/user_profile.dart';
import 'package:himraag/features/auth/providers/user_profile_providers.dart';
import 'package:himraag/features/home/providers/home_providers.dart';
import 'package:himraag/features/library/providers/library_providers.dart';
import 'package:himraag/features/songs/providers/song_collection_providers.dart';

import 'support/test_songs.dart';

class _FakePager implements SongPager {
  _FakePager(List<List<Song>> pages) : _pages = [...pages];

  final List<List<Song>> _pages;
  int calls = 0;
  Object? failNext;
  Completer<void>? gate;

  @override
  bool get hasMore => _pages.isNotEmpty;

  @override
  Future<List<Song>> nextPage() async {
    calls++;
    await gate?.future;
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
    return _pages.removeAt(0);
  }
}

/// The datasource is only constructed (never queried) where it's used here.
class _NoFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSongDatasource implements FirebaseSongDatasource {
  _FakeSongDatasource({this.newReleases = const []});

  final List<Song> newReleases;

  @override
  Future<List<Song>> getNewReleases({int limit = 20}) async => newReleases;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Profile extends StateNotifier<UserProfile>
    implements UserProfileNotifier {
  _Profile(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Favorites extends StateNotifier<Set<String>>
    implements FavoritesNotifier {
  _Favorites() : super(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Lets an async initialisation (awaiting an already-completed seed) finish.
Future<void> _flush() => Future<void>.delayed(Duration.zero);

Future<SongCollectionController> _collection(
  SongCollection collection,
  List<Song> seed, [
  SongPager? pager,
]) async {
  final controller =
      SongCollectionController(collection, seed: Future.value(seed), pager: pager);
  await _flush();
  return controller;
}

void main() {
  const garhwali = SongCollection.region('Garhwali');

  group('SongCollection', () {
    test('See All paths round-trip to the same collection', () {
      for (final c in const [
        SongCollection.recommended,
        SongCollection.trending,
        SongCollection.newReleases,
      ]) {
        final slug = c.path.split('/').last;
        expect(c.path, '/collection/$slug');
        expect(SongCollection.fromSlug(slug), c);
      }
      expect(garhwali.path, '/region/Garhwali');
      expect(garhwali.title, 'Garhwali Songs');
      expect(SongCollection.fromSlug('nope'), isNull);
    });

    test('regional collections only accept their own region', () {
      expect(garhwali.accepts(testSong('g')), isTrue);
      expect(garhwali.accepts(testSong('k', region: 'Kumaoni')), isFalse);
      expect(SongCollection.trending.accepts(testSong('k', region: 'Kumaoni')),
          isTrue);
      expect(SongCollection.trending.accepts(testSong('x', isApproved: false)),
          isFalse);
    });
  });

  group('SongCollectionController', () {
    test('starts from exactly the list the Home row shows', () async {
      final seed = testSongs(3);
      final c = await _collection(SongCollection.trending, seed);

      expect(idsOf(c.songs), idsOf(seed));
      expect(c.state.isLoading, isFalse);
      expect(c.canLoadMore, isFalse);
    });

    test('a region holds only that region — from the row and from pages',
        () async {
      final pager = _FakePager([
        [
          testSong('g2'),
          testSong('k1', region: 'Kumaoni'),
          testSong('h0', region: 'Himachali'),
        ],
      ]);
      final c = await _collection(
        garhwali,
        [testSong('g0'), testSong('k0', region: 'Kumaoni'), testSong('g1')],
        pager,
      );
      expect(idsOf(c.songs), ['g0', 'g1']);

      await c.loadMore();
      expect(idsOf(c.songs), ['g0', 'g1', 'g2']);
      expect(c.songs.every((s) => s.region == 'Garhwali'), isTrue);
    });

    test('appends ranked pages after the row, de-duplicated, without '
        'reordering what is already listed', () async {
      final pager = _FakePager([
        [
          testSong('b', playCount: 9),
          testSong('c', playCount: 1),
          testSong('d', playCount: 7),
        ],
      ]);
      final c = await _collection(
        SongCollection.trending,
        [testSong('a', playCount: 5), testSong('b', playCount: 9)],
        pager,
      );

      await c.loadMore();
      expect(idsOf(c.songs), ['a', 'b', 'd', 'c']);
    });

    test('keeps paging past pages with nothing new instead of stopping early',
        () async {
      final pager = _FakePager([
        [testSong('s0'), testSong('s1')],
        [testSong('s2'), testSong('s3')],
        [testSong('n0')],
      ]);
      final c = await _collection(SongCollection.featured, testSongs(4), pager);

      await c.loadMore();
      expect(idsOf(c.songs), ['s0', 's1', 's2', 's3', 'n0']);
      expect(pager.calls, 3);
      expect(c.canLoadMore, isFalse);
    });

    test('a failed page keeps the loaded songs and can be retried', () async {
      final pager = _FakePager([
        [testSong('n0')],
      ])
        ..failNext = Exception('offline');
      final c = await _collection(SongCollection.trending, testSongs(2), pager);

      await c.loadMore();
      expect(c.state.error, isNotNull);
      expect(idsOf(c.songs), ['s0', 's1']);
      expect(c.canLoadMore, isTrue);

      await c.loadMore();
      expect(c.state.error, isNull);
      expect(idsOf(c.songs), ['s0', 's1', 'n0']);
    });

    test('the list and the player asking at once share one request', () async {
      final pager = _FakePager([
        [testSong('n0')],
      ])
        ..gate = Completer<void>();
      final c = await _collection(SongCollection.trending, testSongs(2), pager);

      final first = c.loadMore();
      final second = c.loadMore();
      pager.gate!.complete();
      await Future.wait([first, second]);

      expect(pager.calls, 1);
      expect(idsOf(c.songs), ['s0', 's1', 'n0']);
    });

    test('unapproved songs never enter a collection', () async {
      final c = await _collection(SongCollection.newReleases,
          [testSong('ok'), testSong('pending', isApproved: false)]);
      expect(idsOf(c.songs), ['ok']);
    });
  });

  group('providers', () {
    test('Made for You has no remote pager; the rest page approved songs',
        () {
      final container = ProviderContainer(overrides: [
        songDatasourceProvider
            .overrideWithValue(FirebaseSongDatasource(_NoFirestore())),
      ]);
      addTearDown(container.dispose);
      final factory = container.read(songPagerFactoryProvider);

      expect(factory(SongCollection.recommended), isNull);
      expect(factory(SongCollection.trending), isA<FirestoreSongPager>());
      expect((factory(garhwali)! as FirestoreSongPager).region, 'Garhwali');
      expect((factory(SongCollection.featured)! as FirestoreSongPager).region,
          isNull);
    });

    test('a queue source serves the collection and grows it', () async {
      final pager = _FakePager([
        testSongs(2, prefix: 'p'),
      ]);
      final container = ProviderContainer(overrides: [
        trendingSongsProvider.overrideWith((ref) async => testSongs(3)),
        songPagerFactoryProvider.overrideWithValue((_) => pager),
      ]);
      addTearDown(container.dispose);

      final source = container
          .read(songCollectionQueueSourceProvider(SongCollection.trending));
      expect(source.hasMore, isTrue, reason: 'still loading the row');

      final songs = await source.loadMore();
      expect(idsOf(songs), ['s0', 's1', 's2', 'p0', 'p1']);
      expect(idsOf(source.songs), idsOf(songs));
      expect(source.hasMore, isFalse);
    });

    test("a regional queue source never yields another region's songs",
        () async {
      final container = ProviderContainer(overrides: [
        regionSongsProvider('Garhwali').overrideWith(
            (ref) async => [testSong('g0'), testSong('k0', region: 'Kumaoni')]),
        songPagerFactoryProvider.overrideWithValue((_) => _FakePager([
              [testSong('g1'), testSong('j0', region: 'Jaunsari')],
            ])),
      ]);
      addTearDown(container.dispose);

      final songs = await container
          .read(songCollectionQueueSourceProvider(garhwali))
          .loadMore();
      expect(idsOf(songs), ['g0', 'g1']);
    });

    test('a Home refresh rebuilds the collection and the queue source follows',
        () async {
      var seed = testSongs(2);
      final container = ProviderContainer(overrides: [
        trendingSongsProvider.overrideWith((ref) async => seed),
        songPagerFactoryProvider.overrideWithValue((_) => null),
      ]);
      addTearDown(container.dispose);
      final source = container
          .read(songCollectionQueueSourceProvider(SongCollection.trending));
      await source.loadMore();
      expect(idsOf(source.songs), ['s0', 's1']);

      seed = testSongs(3, prefix: 'r');
      container.invalidate(trendingSongsProvider);
      await source.loadMore();
      expect(idsOf(source.songs), ['r0', 'r1', 'r2']);
    });

    test('Made for You keeps every ranked pick, not just the 15 on Home',
        () async {
      final container = ProviderContainer(overrides: [
        userProfileProvider.overrideWith((ref) =>
            _Profile(const UserProfile(preferredRegions: ['Garhwali']))),
        favoritesProvider.overrideWith((ref) => _Favorites()),
        localSongsProvider.overrideWith((ref) async => [
              ...testSongs(30),
              ...testSongs(5, prefix: 'k', region: 'Kumaoni'),
            ]),
        trendingSongsProvider.overrideWith((ref) async => const <Song>[]),
      ]);
      addTearDown(container.dispose);

      final picks = await container.read(personalizedSongsProvider.future);
      expect(picks, hasLength(30));
      expect(picks.every((s) => s.region == 'Garhwali'), isTrue);
    });

    test('New Releases are newest first; equal years keep the catalog order',
        () async {
      final container = ProviderContainer(overrides: [
        songDatasourceProvider.overrideWithValue(_FakeSongDatasource(
            newReleases: [testSong('remote', releaseYear: 2025)])),
        localSongsProvider.overrideWith((ref) async => [
              testSong('old', releaseYear: 1996),
              testSong('new1', releaseYear: 2026),
              testSong('mid', releaseYear: 2021),
              testSong('new2', releaseYear: 2026),
            ]),
      ]);
      addTearDown(container.dispose);

      final songs = await container.read(newReleasesProvider.future);
      expect(idsOf(songs), ['new1', 'new2', 'remote', 'mid', 'old']);
    });
  });
}
