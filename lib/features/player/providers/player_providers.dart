import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/services/audio_player_service.dart';
import '../../../domain/models/song.dart';
import '../../../domain/models/user_profile.dart';
import '../../auth/providers/user_profile_providers.dart';
import '../../library/providers/library_providers.dart';

/// The player's queue + current index. Track metadata follows this rather than
/// [playerStateProvider]: a gapless auto-advance keeps PlayerState at
/// ready/playing, so the mini and full players would otherwise keep showing
/// the previous song.
final sequenceStateProvider = StreamProvider<SequenceState?>((ref) {
  return ref.watch(audioPlayerServiceProvider).sequenceStateStream;
});

final currentSongProvider = Provider<Song?>((ref) {
  ref.watch(sequenceStateProvider);
  return ref.watch(audioPlayerServiceProvider).getCurrentSong();
});

/// The queue in play order (shuffled order while shuffle is on).
final currentQueueProvider = Provider<List<Song>>((ref) {
  ref.watch(sequenceStateProvider);
  return ref.watch(audioPlayerServiceProvider).getCurrentQueue();
});

/// Position of the current song within [currentQueueProvider].
final currentQueuePositionProvider = Provider<int?>((ref) {
  ref.watch(sequenceStateProvider);
  return ref.watch(audioPlayerServiceProvider).currentQueuePosition;
});

final playerStateProvider = StreamProvider<PlayerState>((ref) {
  return ref.watch(audioPlayerServiceProvider).playerStateStream;
});

final playerPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioPlayerServiceProvider).positionStream;
});

final playerDurationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(audioPlayerServiceProvider).durationStream;
});

final isPlayingProvider = Provider<bool>((ref) {
  final state = ref.watch(playerStateProvider).valueOrNull;
  return state?.playing ?? false;
});

// Repeat and shuffle mirror the player itself, so the mini player, full player
// and All Songs controls can never disagree with what the queue actually does.
final _repeatModeStreamProvider = StreamProvider<RepeatMode>((ref) {
  return ref.watch(audioPlayerServiceProvider).repeatModeStream;
});

final repeatModeProvider = Provider<RepeatMode>((ref) {
  return ref.watch(_repeatModeStreamProvider).valueOrNull ?? RepeatMode.off;
});

final _shuffleModeStreamProvider = StreamProvider<bool>((ref) {
  return ref.watch(audioPlayerServiceProvider).shuffleModeEnabledStream;
});

final isShuffleProvider = Provider<bool>((ref) {
  return ref.watch(_shuffleModeStreamProvider).valueOrNull ?? false;
});

final playerControllerProvider = Provider<PlayerController>((ref) {
  return PlayerController(ref);
});

/// Records "Continue Listening" progress while a track plays. Kept alive by
/// being watched in [MainShell]. Writes are throttled (see
/// [UserProfileNotifier.setContinueListening]) so we don't hammer Hive/Firestore.
final playbackPersistenceProvider = Provider<void>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  final sub = service.positionStream.listen((pos) {
    final song = service.getCurrentSong();
    final dur = service.duration;
    if (song == null || dur == null || dur.inMilliseconds <= 0) return;
    // Only meaningful, mid-track progress (skip the first 5s and the last 5s).
    if (pos.inSeconds < 5) return;
    if (dur.inMilliseconds - pos.inMilliseconds < 5000) return;
    ref.read(userProfileProvider.notifier).setContinueListening(
          ContinueListening(
            songId: song.id,
            title: song.title,
            artistName: song.artistName,
            artworkUrl: song.artworkUrl,
            audioUrl: song.audioUrl,
            positionMs: pos.inMilliseconds,
            durationMs: dur.inMilliseconds,
            updatedAt: DateTime.now(),
          ),
        );
  });
  ref.onDispose(sub.cancel);
});

/// Adds every track that actually starts playing — including ones the queue
/// advanced to on its own — to Recently Played (and the signed-in play
/// mirror). Failed loads never start, so they are never counted. Kept alive by
/// being watched in [MainShell].
final playbackHistoryProvider = Provider<void>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  final sub = service.trackStartedStream.listen(
    (song) => ref.read(recentlyPlayedProvider.notifier).addSong(song),
  );
  ref.onDispose(sub.cancel);
});

class PlayerController {
  PlayerController(this._ref);

  final Ref _ref;

  AudioPlayerService get _service => _ref.read(audioPlayerServiceProvider);

  /// Plays [song] within [queue] (just [song] when omitted). With a [source],
  /// the queue keeps growing from it so playback continues past [queue].
  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    int? queueIndex,
    QueueSource? source,
  }) {
    final songs = queue ?? [song];
    return _service.playQueue(
      songs,
      index: queueIndex ?? max(0, songs.indexWhere((s) => s.id == song.id)),
      source: source,
    );
  }

  /// "Play" / "Play All": turns shuffle off and plays [songs] in order from
  /// the first. (Tapping a song keeps the user's shuffle setting instead.)
  Future<void> playAll(List<Song> songs, {QueueSource? source}) {
    if (songs.isEmpty) return Future.value();
    return _service.playQueue(songs, source: source, shuffle: false);
  }

  /// Turns shuffle on and plays [songs] from a random song; the whole queue —
  /// and anything [source] adds later — plays in shuffled order.
  Future<void> shufflePlay(List<Song> songs, {QueueSource? source}) {
    if (songs.isEmpty) return Future.value();
    return _service.playQueue(
      songs,
      index: Random().nextInt(songs.length),
      source: source,
      shuffle: true,
    );
  }

  /// Resumes [song] at [start] — used by the Home "Continue Listening" rail.
  /// [queue]/[source] let playback continue after it instead of stopping.
  Future<void> playSongAt(
    Song song,
    Duration start, {
    List<Song>? queue,
    QueueSource? source,
  }) {
    final songs = queue ?? [song];
    return _service.playQueue(
      songs,
      index: max(0, songs.indexWhere((s) => s.id == song.id)),
      initialPosition: start,
      source: source,
    );
  }

  Future<void> togglePlayPause() async {
    if (_service.isPlaying) {
      await _service.pause();
    } else {
      await _service.play();
    }
  }

  Future<void> skipToNext() => _service.skipToNext();
  Future<void> skipToPrevious() => _service.skipToPrevious();
  Future<void> seekTo(Duration position) => _service.seekTo(position);

  Future<void> cycleRepeatMode() {
    final current = _ref.read(repeatModeProvider);
    return setRepeatMode(
        RepeatMode.values[(current.index + 1) % RepeatMode.values.length]);
  }

  Future<void> setRepeatMode(RepeatMode mode) => _service.setRepeatMode(mode);

  Future<void> toggleShuffle() =>
      _service.setShuffle(!_service.shuffleModeEnabled);

  Future<void> addToQueue(Song song) => _service.addToQueue(song);
  Future<void> addToQueueNext(Song song) => _service.addToQueueNext(song);

  /// [position] is the song's place in the queue as shown (play order).
  Future<void> removeFromQueue(int position) =>
      _service.removeFromQueue(position);

  /// [position] is the song's place in the queue as shown (play order).
  Future<void> playFromQueue(int position) => _service.playFromQueue(position);
}
