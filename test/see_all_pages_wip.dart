import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:himraag/core/router/app_router.dart';
import 'package:himraag/data/services/audio_player_service.dart';
import 'package:himraag/domain/models/song.dart';
import 'package:himraag/features/home/providers/home_providers.dart';
import 'package:himraag/features/songs/providers/song_collection_providers.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'support/fake_just_audio_platform.dart';
import 'support/test_songs.dart';

class _OnePagePager implements SongPager {
  _OnePagePager(this._page);

  List<Song>? _page;

  @override
  bool get hasMore => _page != null;

  @override
  Future<List<Song>> nextPage() async {
    final page = _page ?? const <Song>[];
    _page = null;
    return page;
  }
}

void main() {
  late AudioPlayerService service;

  setUp(() {
    JustAudioPlatform.instance = FakeJustAudioPlatform();
    service = AudioPlayerService();
  });

  tearDown(() => service.dispose());

  /// The real See All routes, plus a stand-in for the full player they open.
  Future<void> pumpPage(
    WidgetTester tester,
    String location, {
    SongPagerFactory pagers = _noPager,
  }) async {
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/player',
          builder: (_, __) => const Scaffold(body: Text('Full player')),
        ),
        ...songCollectionRoutes(),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioPlayerServiceProvider.overrideWithValue(service),
        songPagerFactoryProvider.overrideWithValue(pagers),
        trendingSongsProvider.overrideWith((ref) async => testSongs(30)),
        newReleasesProvider
            .overrideWith((ref) async => testSongs(4, prefix: 'n')),
        personalizedSongsProvider
            .overrideWith((ref) async => testSongs(20, prefix: 'm')),
        regionSongsProvider('Garhwali').overrideWith((ref) async => [
              testSong('g0'),
              testSong('k0', region: 'Kumaoni'),
              testSong('g1'),
            ]),
        regionSongsProvider('Sirmauri')
            .overrideWith((ref) async => const <Song>[]),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('each See All path opens its own collection page',
      (tester) async {
    final expected = {
      SongCollection.trending: 'Song s0',
      SongCollection.newReleases: 'Song n0',
      SongCollection.recommended: 'Song m0',
      const SongCollection.region('Garhwali'): 'Song g0',
    };
    for (final MapEntry(key: collection, value: firstSong)
        in expected.entries) {
      await pumpPage(tester, collection.path);
      expect(find.text(collection.title), findsOneWidget);
      expect(find.text(firstSong), findsOneWidget);
    }
  });

  testWidgets('a regional page lists only that region', (tester) async {
    await pumpPage(tester, '/region/Garhwali');

    expect(find.text('Song g0'), findsOneWidget);
    expect(find.text('Song g1'), findsOneWidget);
    expect(find.text('Song k0'), findsNothing);
    expect(find.text('2 songs'), findsOneWidget);
  });

  testWidgets('an empty region shows its empty state', (tester) async {
    await pumpPage(tester, '/region/Sirmauri');
    expect(find.text('No Sirmauri songs yet'), findsOneWidget);
  });

  testWidgets('tapping a song queues the whole collection, not the rows on '
      'screen', (tester) async {
    await pumpPage(tester, SongCollection.trending.path);

    await tester.tap(find.text('Song s2'));
    await tester.pumpAndSettle();

    expect(find.text('Full player'), findsOneWidget);
    expect(service.getCurrentSong()?.id, 's2');
    expect(idsOf(service.getCurrentQueue()), idsOf(testSongs(30)));
  });

  testWidgets('Shuffle shuffles the whole collection', (tester) async {
    await pumpPage(tester, SongCollection.trending.path);

    await tester.tap(find.text('Shuffle'));
    await tester.pumpAndSettle();

    expect(service.shuffleModeEnabled, isTrue);
    expect(idsOf(service.getCurrentQueue()).toSet(),
        idsOf(testSongs(30)).toSet());
  });

  testWidgets('Play starts from the top, in order', (tester) async {
    await service.setShuffle(true);
    await pumpPage(tester, SongCollection.newReleases.path);

    await tester.tap(find.text('Play'));
    await tester.pumpAndSettle();

    expect(service.shuffleModeEnabled, isFalse);
    expect(service.getCurrentSong()?.id, 'n0');
    expect(idsOf(service.getCurrentQueue()), ['n0', 'n1', 'n2', 'n3']);
  });

  testWidgets('loads further songs when the end of the list is reached',
      (tester) async {
    await pumpPage(
      tester,
      '/region/Garhwali',
      pagers: (_) => _OnePagePager([
        testSong('g2'),
        testSong('j0', region: 'Jaunsari'),
      ]),
    );

    expect(find.text('Song g2'), findsOneWidget);
    expect(find.text('Song j0'), findsNothing);
    expect(find.text('3 songs'), findsOneWidget);
  });
}

SongPager? _noPager(SongCollection _) => null;
