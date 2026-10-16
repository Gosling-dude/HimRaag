import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:himraag/data/services/audio_player_service.dart';
import 'package:himraag/domain/models/song.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'support/fake_just_audio_platform.dart';
import 'support/test_songs.dart';

/// Queue behaviour of [AudioPlayerService] running the real just_audio player
/// against [FakeJustAudioPlatform]. These are unit tests of the queue logic —
/// not proof of audio output, buffering or lock-screen behaviour on a device.

/// A [QueueSource] that hands out [pages] one per [loadMore].
class _PagedSource implements QueueSource {
  _PagedSource(List<Song> initial, [List<List<Song>> pages = const []])
      : songs = [...initial],
        _pages = [...pages];

  @override
  final List<Song> songs;
  final List<List<Song>> _pages;
  int loads = 0;

  /// While set, [loadMore] waits on it — a slow network page.
  Completer<void>? gate;

  @override
  bool get hasMore => _pages.isNotEmpty;

  @override
  Future<List<Song>> loadMore() async {
    loads++;
    await gate?.future;
    if (_pages.isNotEmpty) songs.addAll(_pages.removeAt(0));
    return songs;
  }
}

Future<void> _settle([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const grace = Duration(milliseconds: 40);
  const stall = Duration(milliseconds: 150);

  late FakeJustAudioPlatform platform;
  late AudioPlayerService service;

  setUp(() {
    platform = FakeJustAudioPlatform();
    JustAudioPlatform.instance = platform;
    service =
        AudioPlayerService(failureGracePeriod: grace, stallTimeout: stall);
  });

  tearDown(() => service.dispose());

  String? current() => service.getCurrentSong()?.id;
  List<String> queue() => idsOf(service.getCurrentQueue());

  Future<void> finishTrack() async {
    platform.player.finishTrack();
    await _settle();
  }

  group('queue context', () {
    test('a song from the Home banner queues the whole catalog, not the slides',
        () async {
      final catalog = testSongs(40);

      // The banner shows the first five songs; tapping the third passes the
      // full featured list and its index.
      await service.playQueue(catalog, index: 2, source: _PagedSource(catalog));
      await _settle();

      expect(current(), 's2');
      expect(queue(), idsOf(catalog));
      expect(platform.player.urls, hasLength(40));
      expect(service.isPlaying, isTrue);
    });

    test('a finished song advances to the next queued song', () async {
      await service.playQueue(testSongs(3));
      await _settle();

      await finishTrack();
      expect(current(), 's1');
      await finishTrack();
      expect(current(), 's2');
      expect(service.isPlaying, isTrue);
    });

    test('playback continues past the initially loaded songs', () async {
      final firstPage = testSongs(5);
      final nextPage = testSongs(5, prefix: 'p');
      final source = _PagedSource(firstPage, [nextPage]);

      await service.playQueue(firstPage, source: source);
      await _settle();
      expect(queue(), hasLength(5), reason: 'plenty left — no fetch yet');

      // Three songs left after the current one: the next page is queued now,
      // before the first page runs out.
      await finishTrack();
      expect(source.loads, 1);
      expect(queue(), [...idsOf(firstPage), ...idsOf(nextPage)]);

      for (var i = 0; i < 4; i++) {
        await finishTrack();
      }
      expect(current(), 'p0');
      expect(service.isPlaying, isTrue);
    });

    test('a short queue is extended as soon as it starts', () async {
      final source = _PagedSource([testSong('only')], [testSongs(3)]);

      await service.playQueue([testSong('only')], source: source);
      await _settle();

      expect(queue(), ['only', 's0', 's1', 's2']);
      await finishTrack();
      expect(current(), 's0');
    });

    test('expansion never adds duplicates', () async {
      final source = _PagedSource(testSongs(3), [
        [testSong('s1'), testSong('n0'), testSong('n0'), testSong('s2')],
        [testSong('n1'), testSong('s0'), testSong('n0')],
      ]);

      await service.playQueue(testSongs(3), source: source);
      await _settle();
      for (var i = 0; i < 3; i++) {
        await finishTrack();
      }

      expect(queue(), ['s0', 's1', 's2', 'n0', 'n1']);
      expect(queue().toSet(), hasLength(queue().length));
    });

    test('duplicates in the requested list are dropped and the start follows '
        'the selected song', () async {
      final songs = [testSong('a'), testSong('b'), testSong('a'), testSong('c')];

      await service.playQueue(songs, index: 3);
      await _settle();

      expect(queue(), ['a', 'b', 'c']);
      expect(current(), 'c');
    });

    test('starting another collection replaces the queue and drops the old '
        "collection's late page", () async {
      final garhwali = testSongs(2, prefix: 'g');
      final source = _PagedSource(garhwali, [testSongs(3, prefix: 'g-more')])
        ..gate = Completer<void>();

      await service.playQueue(garhwali, source: source);
      await _settle(); // its page request is now in flight
      expect(source.loads, 1);

      final kumaoni = testSongs(4, prefix: 'k');
      await service.playQueue(kumaoni);
      source.gate!.complete();
      await _settle();

      expect(queue(), idsOf(kumaoni));
      expect(current(), 'k0');
    });

    test('Continue Listening resumes at the saved position within the queue',
        () async {
      await service.playQueue(testSongs(5),
          index: 2, initialPosition: const Duration(seconds: 75));
      await _settle();

      expect(platform.loads.last.initialIndex, 2);
      expect(platform.loads.last.initialPosition, const Duration(seconds: 75));
      expect(current(), 's2');
    });

    test('the end of a complete queue stops, or loops with repeat-all',
        () async {
      await service.playQueue(testSongs(2), index: 1);
      await _settle();
      await finishTrack();
      expect(platform.player.state, ProcessingStateMessage.completed);

      await service.setRepeatMode(RepeatMode.all);
      await service.playQueue(testSongs(2), index: 1);
      await _settle();
      await finishTrack();
      expect(current(), 's0');
    });
  });

  group('shuffle', () {
    test('shuffles the whole queue and keeps the current song', () async {
      final songs = testSongs(50);
      await service.playQueue(songs, index: 7);
      await _settle();

      await service.setShuffle(true);
      await _settle();

      final shuffled = queue();
      expect(shuffled.first, 's7');
      expect(shuffled.toSet(), idsOf(songs).toSet());
      expect(current(), 's7');
      expect(platform.player.shuffleMode, isTrue);
      expect(platform.player.shuffleOrder.first, 7);
    });

    test('songs added mid-playback while shuffled come after the current song',
        () async {
      final more = testSongs(20, prefix: 'p');
      final source = _PagedSource(testSongs(10), [more]);
      await service.playQueue(testSongs(10), source: source, shuffle: true);
      await _settle();

      // Play into the shuffled order until only three songs are left.
      for (var i = 0; i < 6; i++) {
        await finishTrack();
      }
      expect(source.loads, 1);

      final position = service.currentQueuePosition!;
      final upcoming = queue().sublist(position + 1);
      expect(upcoming, containsAll(idsOf(more)));
    });

    test('turning shuffle off restores the original order', () async {
      await service.playQueue(testSongs(10), index: 3, shuffle: true);
      await _settle();

      await service.setShuffle(false);
      await _settle();

      expect(queue(), idsOf(testSongs(10)));
      expect(current(), 's3');
      await finishTrack();
      expect(current(), 's4');
    });

    test('queue positions follow the shuffled order shown', () async {
      await service.playQueue(testSongs(10), shuffle: true);
      await _settle();
      final shown = queue();

      await service.playFromQueue(4);
      await _settle();

      expect(current(), shown[4]);
    });
  });

  group('seeking', () {
    test('moves within the current song without touching the queue',
        () async {
      await service.playQueue(testSongs(30), index: 4);
      await _settle();
      final before = queue();
      final loads = platform.loads.length;

      await service.seekTo(const Duration(seconds: 42));
      await _settle();

      expect(platform.player.position, const Duration(seconds: 42));
      expect(current(), 's4');
      expect(queue(), before);
      expect(platform.loads, hasLength(loads), reason: 'no reload');
    });
  });

  group('failures', () {
    test('a song that fails to load is skipped', () async {
      platform.failingUrls.add(songUrl('s0'));

      await service.playQueue(testSongs(5));
      await _settle();

      expect(current(), 's1');
      expect(service.isPlaying, isTrue);
      expect(queue(), hasLength(5), reason: 'the queue survives');
    });

    test('a song failing mid-queue is skipped after the grace period',
        () async {
      platform.failingUrls.add(songUrl('s1'));
      await service.playQueue(testSongs(4));
      await _settle();

      await finishTrack(); // onto the failing s1
      await _settle(grace.inMilliseconds * 3);

      expect(current(), 's2');
      expect(service.isPlaying, isTrue);
    });

    test('a swallowed error (background plugin) is caught by the stall check',
        () async {
      platform
        ..swallowErrors = true
        ..failingUrls.add(songUrl('s1'));
      await service.playQueue(testSongs(4));
      await _settle();

      await finishTrack();
      await _settle(grace.inMilliseconds * 2);
      expect(current(), 's1', reason: 'only a stall can reveal it');

      await _settle(stall.inMilliseconds * 2);
      expect(current(), 's2');
    });

    test('stops retrying after repeated failures instead of looping', () async {
      final songs = testSongs(8);
      platform.failingUrls.addAll(songs.map((s) => songUrl(s.id)));

      await service.playQueue(songs);
      await _settle(200);

      // The first attempt plus maxConsecutiveFailures skips, then it pauses.
      expect(platform.loads,
          hasLength(AudioPlayerService.maxConsecutiveFailures + 1));
      expect(service.isPlaying, isFalse);
      await _settle(200);
      expect(platform.loads,
          hasLength(AudioPlayerService.maxConsecutiveFailures + 1));
    });

    test('only songs that actually start playing are reported for history',
        () async {
      platform.failingUrls.add(songUrl('s0'));
      final started = <String>[];
      final sub = service.trackStartedStream.listen((s) => started.add(s.id));

      await service.playQueue(testSongs(3));
      await _settle();
      await finishTrack();

      expect(started, ['s1', 's2']);
      await sub.cancel();
    });
  });

  group('UpcomingShuffleOrder', () {
    test('inserts new items only after the current one', () {
      var current = 3;
      final order = UpcomingShuffleOrder(() => current, random: Random(1))
        ..insert(0, 6);
      order.shuffle(initialIndex: 3);
      // Pretend playback has moved four songs into the shuffled order.
      current = order.indices[4];

      order.insert(6, 10);

      final currentPosition = order.indices.indexOf(current);
      final added = List.generate(10, (i) => 6 + i);
      for (final index in added) {
        expect(order.indices.indexOf(index), greaterThan(currentPosition));
      }
      expect(order.indices.toSet(), List.generate(16, (i) => i).toSet());
    });
  });
}
