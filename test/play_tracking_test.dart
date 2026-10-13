import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:himraag/data/services/play_tracking.dart';

class _MemoryStore implements PendingPlayStore {
  _MemoryStore([Map<String, int>? initial]) : saved = {...?initial};
  Map<String, int> saved;

  @override
  Map<String, int> load() => {...saved};

  @override
  Future<void> save(Map<String, int> plays) async => saved = {...plays};
}

const _s = Duration(seconds: 1);

/// Simulates [seconds] of continuous playback in 250 ms ticks; returns the
/// ids counted.
List<String> _listen(
  PlaySessionTracker t,
  String id, {
  required int fromSecond,
  required int seconds,
  Duration? length = const Duration(minutes: 4),
}) {
  final counted = <String>[];
  for (var ms = fromSecond * 1000; ms <= (fromSecond + seconds) * 1000; ms += 250) {
    final hit = t.onTick(id, Duration(milliseconds: ms), length);
    if (hit != null) counted.add(hit);
  }
  return counted;
}

void main() {
  group('PlaySessionTracker', () {
    test('counts once after 30 s of listening', () {
      final t = PlaySessionTracker();
      expect(_listen(t, 'a', fromSecond: 0, seconds: 29), isEmpty);
      expect(_listen(t, 'a', fromSecond: 29, seconds: 200), ['a']);
    });

    test('seeking forward is not listening', () {
      final t = PlaySessionTracker();
      _listen(t, 'a', fromSecond: 0, seconds: 10);
      // Jump to 3:00 then listen 10 s more: only ~20 s actually heard.
      expect(_listen(t, 'a', fromSecond: 180, seconds: 10), isEmpty);
      expect(_listen(t, 'a', fromSecond: 190, seconds: 15), ['a']);
    });

    test('switching songs resets progress', () {
      final t = PlaySessionTracker();
      _listen(t, 'a', fromSecond: 0, seconds: 25);
      expect(_listen(t, 'b', fromSecond: 0, seconds: 25), isEmpty);
      expect(_listen(t, 'b', fromSecond: 25, seconds: 10), ['b']);
    });

    test('replaying from the start counts again (repeat-one)', () {
      final t = PlaySessionTracker();
      expect(_listen(t, 'a', fromSecond: 0, seconds: 40), ['a']);
      expect(_listen(t, 'a', fromSecond: 0, seconds: 40), ['a']);
    });

    test('short tracks count at half their length', () {
      final t = PlaySessionTracker();
      const length = Duration(seconds: 40);
      expect(t.thresholdFor(length), const Duration(seconds: 20));
      expect(_listen(t, 'a', fromSecond: 0, seconds: 21, length: length), ['a']);
      expect(t.thresholdFor(null), _s * 30);
    });

    test('no song loaded never counts', () {
      final t = PlaySessionTracker();
      for (var i = 0; i < 100; i++) {
        expect(t.onTick(null, Duration(seconds: i), null), isNull);
      }
    });
  });

  group('PlayReporter', () {
    test('buffers until the threshold, then flushes one batch', () async {
      final sent = <Map<String, int>>[];
      final store = _MemoryStore();
      final r = PlayReporter(
        store: store,
        send: (p) async => sent.add(p),
        flushThreshold: 3,
      );
      await r.record('a');
      await r.record('b');
      expect(sent, isEmpty);
      expect(store.saved, {'a': 1, 'b': 1});

      await r.record('a');
      await r.flush(); // joins the flush started by record()
      expect(sent, [
        {'a': 2, 'b': 1}
      ]);
      expect(r.pending, isEmpty);
      expect(store.saved, isEmpty);
    });

    test('keeps plays when sending fails, and retries later', () async {
      var fail = true;
      final sent = <Map<String, int>>[];
      final r = PlayReporter(
        store: _MemoryStore(),
        send: (p) async {
          if (fail) throw Exception('offline');
          sent.add(p);
        },
        flushThreshold: 100,
      );
      await r.record('a');
      await r.flush();
      expect(r.pending, {'a': 1});

      fail = false;
      await r.flush();
      expect(sent, [
        {'a': 1}
      ]);
      expect(r.pending, isEmpty);
    });

    test('plays recorded during a flush are not lost', () async {
      final gate = Completer<void>();
      final r = PlayReporter(
        store: _MemoryStore(),
        send: (_) => gate.future,
        flushThreshold: 100,
      );
      await r.record('a');
      final flushing = r.flush();
      await r.record('a'); // arrives mid-flight
      gate.complete();
      await flushing;
      expect(r.pending, {'a': 1});
    });

    test('restores pending plays from storage after a restart', () {
      final r = PlayReporter(
        store: _MemoryStore({'a': 4}),
        send: (_) async {},
      );
      expect(r.pendingTotal, 4);
    });

    test('splits into server-sized batches and clamps per-song counts',
        () async {
      final initial = {for (var i = 0; i < 60; i++) 's$i': 1, 'hot': 25};
      final sent = <Map<String, int>>[];
      final r = PlayReporter(
        store: _MemoryStore(initial),
        send: (p) async => sent.add(p),
      );
      await r.flush();
      expect(sent.length, 2);
      expect(sent.every((b) => b.length <= PlayReporter.maxSongsPerCall), isTrue);
      expect(sent.expand((b) => b.entries).firstWhere((e) => e.key == 'hot').value,
          PlayReporter.maxPlaysPerSongPerCall);
      // The 5 plays over the per-call cap wait for the next flush.
      expect(r.pending, {'hot': 5});
    });

    test('stops buffering at maxPending', () async {
      final r = PlayReporter(
        store: _MemoryStore(),
        send: (_) async => throw Exception('offline'),
        flushThreshold: 1000,
        maxPending: 3,
      );
      for (var i = 0; i < 10; i++) {
        await r.record('a');
      }
      expect(r.pendingTotal, 3);
    });
  });
}
