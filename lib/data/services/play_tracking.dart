import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/hive_boxes.dart';
import 'audio_player_service.dart';
import 'media_url_resolver.dart';

/// Decides when listening to the current track counts as one play.
///
/// A play is counted once per track activation, after [minListen] of actual
/// listening (or half the track, for tracks shorter than 2 × [minListen]).
/// Seeking forward does not count as listening; replaying from the start
/// (manual restart or repeat-one) starts a new activation.
class PlaySessionTracker {
  PlaySessionTracker({this.minListen = const Duration(seconds: 30)});

  final Duration minListen;

  /// Position jumps larger than this are treated as seeks, not listening.
  static const Duration _maxTick = Duration(seconds: 3);

  String? _songId;
  Duration _lastPosition = Duration.zero;
  Duration _listened = Duration.zero;
  bool _counted = false;

  Duration thresholdFor(Duration? trackLength) {
    if (trackLength == null || trackLength <= Duration.zero) return minListen;
    final half = trackLength ~/ 2;
    return half < minListen ? half : minListen;
  }

  /// Feed every position update. Returns the song id when this tick
  /// completes a play, else null.
  String? onTick(String? songId, Duration position, Duration? trackLength) {
    if (songId != _songId) {
      _songId = songId;
      _lastPosition = position;
      _listened = Duration.zero;
      _counted = false;
      return null;
    }
    if (songId == null) return null;

    final delta = position - _lastPosition;
    _lastPosition = position;

    if (delta > Duration.zero && delta <= _maxTick) {
      _listened += delta;
    } else if (delta < Duration.zero && position < _maxTick) {
      // Back to the start of the same track: a fresh listen.
      _listened = Duration.zero;
      _counted = false;
    }

    if (!_counted && _listened >= thresholdFor(trackLength)) {
      _counted = true;
      return songId;
    }
    return null;
  }
}

/// Durable storage for plays not yet sent to the server.
abstract class PendingPlayStore {
  Map<String, int> load();
  Future<void> save(Map<String, int> plays);
}

class HivePendingPlayStore implements PendingPlayStore {
  static const String _key = 'pending_plays';

  @override
  Map<String, int> load() {
    final raw = HiveBoxes.settings.get(_key);
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if (e.key is String && e.value is int) e.key as String: e.value as int,
    };
  }

  @override
  Future<void> save(Map<String, int> plays) =>
      HiveBoxes.settings.put(_key, Map<String, int>.of(plays));
}

/// Sends one batch (≤ [PlayReporter.maxSongsPerCall] songs) to the server.
typedef PlaySender = Future<void> Function(Map<String, int> plays);

/// Buffers plays locally and flushes them in batches, so a typical listener
/// costs one or two server calls a day instead of one per song.
///
/// Plays survive app restarts and offline periods (persisted in [store]).
/// A failed flush keeps everything for the next attempt; plays recorded
/// while a flush is in flight are never lost.
class PlayReporter {
  PlayReporter({
    required PendingPlayStore store,
    required PlaySender send,
    this.flushThreshold = 10,
    this.maxPending = 500,
  })  : _store = store,
        _send = send,
        _pending = store.load();

  /// Matches MAX_SONGS_PER_CALL in backend/functions/src/logic/plays.ts.
  static const int maxSongsPerCall = 50;

  /// Matches MAX_PLAYS_PER_SONG_PER_CALL on the server.
  static const int maxPlaysPerSongPerCall = 20;

  final PendingPlayStore _store;
  final PlaySender _send;
  final int flushThreshold;

  /// Stop buffering beyond this many plays (e.g. months offline).
  final int maxPending;

  final Map<String, int> _pending;
  Future<void>? _inFlight;

  Map<String, int> get pending => Map.unmodifiable(_pending);
  int get pendingTotal => _pending.values.fold(0, (a, b) => a + b);

  Future<void> record(String songId) async {
    if (pendingTotal >= maxPending) return;
    _pending.update(songId, (n) => n + 1, ifAbsent: () => 1);
    await _store.save(_pending);
    if (pendingTotal >= flushThreshold) unawaited(flush());
  }

  /// Sends everything pending. Concurrent calls share the same flush.
  Future<void> flush() => _inFlight ??= _flush().whenComplete(() {
        _inFlight = null;
      });

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    for (final batch in _batches(Map.of(_pending))) {
      try {
        await _send(batch);
      } catch (e) {
        debugPrint('[PLAYS] flush failed, keeping $pendingTotal plays: $e');
        return;
      }
      // Subtract only what was sent; plays recorded meanwhile stay pending.
      batch.forEach((songId, sent) {
        final left = (_pending[songId] ?? 0) - sent;
        if (left > 0) {
          _pending[songId] = left;
        } else {
          _pending.remove(songId);
        }
      });
      await _store.save(_pending);
    }
  }

  static Iterable<Map<String, int>> _batches(Map<String, int> all) sync* {
    var batch = <String, int>{};
    for (final e in all.entries) {
      batch[e.key] =
          e.value > maxPlaysPerSongPerCall ? maxPlaysPerSongPerCall : e.value;
      if (batch.length == maxSongsPerCall) {
        yield batch;
        batch = {};
      }
    }
    if (batch.isNotEmpty) yield batch;
  }
}

/// Calls the `recordPlays` Cloud Function (requires a signed-in user; plays
/// stay buffered until one is available).
Future<void> sendPlaysToCloud(Map<String, int> plays) async {
  final user = signedInUser(FirebaseAuth.instance);
  if (user == null) throw StateError('no Firebase user — will retry later');
  await FirebaseFunctions.instanceFor(region: 'asia-south1')
      .httpsCallable('recordPlays')
      .call<Map<String, dynamic>>({'plays': plays});
}

final playReporterProvider = Provider<PlayReporter>((ref) {
  return PlayReporter(store: HivePendingPlayStore(), send: sendPlaysToCloud);
});

/// Watches the player and records plays. Keep alive by watching it from the
/// app root (see HimRaagApp).
final playTrackingProvider = Provider<void>((ref) {
  final audio = ref.watch(audioPlayerServiceProvider);
  final reporter = ref.watch(playReporterProvider);
  final tracker = PlaySessionTracker();

  final sub = audio.positionStream.listen((position) {
    final songId = tracker.onTick(audio.currentSongId, position, audio.duration);
    if (songId == null) return;
    debugPrint('[PLAYS] counted play: $songId');
    unawaited(reporter.record(songId));
    unawaited(FirebaseAnalytics.instance
        .logEvent(name: 'song_play', parameters: {'song_id': songId})
        .catchError((Object e) => debugPrint('[PLAYS] analytics: $e')));
  });

  // Safety net for light listeners who never reach the threshold.
  final timer = Timer.periodic(const Duration(minutes: 15), (_) {
    unawaited(reporter.flush());
  });

  ref.onDispose(() {
    sub.cancel();
    timer.cancel();
  });
});
