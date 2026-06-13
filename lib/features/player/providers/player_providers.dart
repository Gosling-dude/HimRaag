import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/services/audio_player_service.dart';
import '../../../domain/models/song.dart';
import '../../library/providers/library_providers.dart';

final currentSongProvider = Provider<Song?>((ref) {
  ref.watch(playerStateProvider);
  return ref.watch(audioPlayerServiceProvider).getCurrentSong();
});

final currentQueueProvider = Provider<List<Song>>((ref) {
  ref.watch(playerStateProvider);
  return ref.watch(audioPlayerServiceProvider).getCurrentQueue();
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

final repeatModeProvider = StateProvider<RepeatMode>((ref) => RepeatMode.off);

final isShuffleProvider = StateProvider<bool>((ref) => false);

final playerControllerProvider = Provider<PlayerController>((ref) {
  return PlayerController(ref);
});

class PlayerController {
  PlayerController(this._ref);

  final Ref _ref;

  AudioPlayerService get _service => _ref.read(audioPlayerServiceProvider);

  Future<void> playSong(Song song, {List<Song>? queue, int? queueIndex}) async {
    await _service.playSong(song, queue: queue, queueIndex: queueIndex);
    _ref.read(recentlyPlayedProvider.notifier).addSong(song);
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

  Future<void> cycleRepeatMode() async {
    final current = _ref.read(repeatModeProvider);
    final next =
        RepeatMode.values[(current.index + 1) % RepeatMode.values.length];
    _ref.read(repeatModeProvider.notifier).state = next;
    await _service.setRepeatMode(next);
  }

  Future<void> toggleShuffle() async {
    final current = _ref.read(isShuffleProvider);
    _ref.read(isShuffleProvider.notifier).state = !current;
    await _service.setShuffle(!current);
  }

  Future<void> addToQueue(Song song) => _service.addToQueue(song);
  Future<void> addToQueueNext(Song song) => _service.addToQueueNext(song);
  Future<void> removeFromQueue(int index) => _service.removeFromQueue(index);
  Future<void> playFromQueue(int index) => _service.playFromQueue(index);
}
