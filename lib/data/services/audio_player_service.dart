import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/song.dart';
import 'media_url_resolver.dart';

enum RepeatMode { off, one, all }

/// The URI the player should open for [song]: the local file when
/// downloaded, else the CDN URL (with [token] on protected audio paths).
Uri playbackUriFor(Song song, String? token, MediaUrlResolver resolver) =>
    song.isDownloaded
        ? Uri.file(song.localPath!)
        : resolver.authorize(song.audioUrl, token);

class AudioPlayerService {
  AudioPlayerService({
    AudioPlayer? player,
    MediaTokenProvider? mediaToken,
    MediaUrlResolver resolver = MediaUrlResolver.current,
  })  : _player = player ?? AudioPlayer(),
        _mediaToken = mediaToken ?? (() async => null),
        _resolver = resolver {
    // Surface engine-level state + errors. Without this, a failed load (e.g. a
    // broken audio platform or an unreachable URL) is invisible: the future
    // throws into a fire-and-forget call site and is swallowed.
    _player.playerStateStream.listen(
      (state) => debugPrint(
        '[AUDIO] PLAYER_STATE processing=${state.processingState} '
        'playing=${state.playing}',
      ),
      onError: (Object e, StackTrace st) =>
          debugPrint('[AUDIO] PLAYBACK_ERROR (stateStream): $e\n$st'),
    );
    _player.playbackEventStream.listen(
      (_) {},
      onError: (Object e, StackTrace st) =>
          debugPrint('[AUDIO] PLAYBACK_ERROR (eventStream): $e\n$st'),
    );
  }

  final AudioPlayer _player;
  final MediaTokenProvider _mediaToken;
  final MediaUrlResolver _resolver;

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<double> get volumeStream => _player.volumeStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  int? get currentIndex => _player.currentIndex;

  /// Id of the song currently loaded, or null. Cheaper than [getCurrentSong]
  /// for per-tick listeners such as play tracking.
  String? get currentSongId {
    final tag = _player.sequenceState?.currentSource?.tag;
    return tag is MediaItem ? tag.id : null;
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? queueIndex}) async {
    final songs = queue ?? [song];
    final index = queueIndex ?? 0;

    debugPrint(
      '[AUDIO] PLAY_REQUEST id=${song.id} title="${song.title}" '
      'queueLength=${songs.length} index=$index',
    );
    debugPrint('[AUDIO] AUDIO_URL ${song.isDownloaded ? song.localPath : _resolver.resolve(song.audioUrl)}');

    if (!song.isDownloaded &&
        (song.audioUrl.isEmpty || Uri.tryParse(song.audioUrl) == null)) {
      debugPrint('[AUDIO] PLAYBACK_ERROR invalid/empty audioUrl: "${song.audioUrl}"');
      return;
    }

    try {
      // One token for the whole queue; the CDN accepts it for hours past
      // expiry (TOKEN_GRACE_SECONDS), which covers a long listening session.
      final token = await _mediaToken();
      final playlist = ConcatenatingAudioSource(
        children: songs.map((s) => buildAudioSource(s, token)).toList(),
      );

      debugPrint('[AUDIO] SET_AUDIO_SOURCE initialIndex=$index');
      // A broken audio platform makes setAudioSource hang forever (no error,
      // no duration). Time-box it so the failure becomes a visible error
      // instead of a silent freeze.
      final duration = await _player
          .setAudioSource(playlist, initialIndex: index, preload: true)
          .timeout(const Duration(seconds: 20));
      debugPrint('[AUDIO] SONG_LOADED duration=$duration');

      await _player.play();
    } catch (e, st) {
      debugPrint('[AUDIO] PLAYBACK_ERROR playSong failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> playFromQueue(int index) async {
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  Future<void> seekTo(Duration position) => _player.seek(position);

  Future<void> skipToNext() => _player.seekToNext();
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    switch (mode) {
      case RepeatMode.off:
        await _player.setLoopMode(LoopMode.off);
      case RepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
      case RepeatMode.all:
        await _player.setLoopMode(LoopMode.all);
    }
  }

  Future<void> setShuffle(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
    if (enabled) await _player.shuffle();
  }

  Future<void> addToQueue(Song song) async {
    final source = buildAudioSource(song, await _mediaToken());
    final sequence = _player.audioSource;
    if (sequence is ConcatenatingAudioSource) {
      await sequence.add(source);
    }
  }

  Future<void> addToQueueNext(Song song) async {
    final source = buildAudioSource(song, await _mediaToken());
    final sequence = _player.audioSource;
    if (sequence is ConcatenatingAudioSource) {
      final nextIndex = (_player.currentIndex ?? 0) + 1;
      await sequence.insert(nextIndex, source);
    }
  }

  Future<void> removeFromQueue(int index) async {
    final sequence = _player.audioSource;
    if (sequence is ConcatenatingAudioSource) {
      await sequence.removeAt(index);
    }
  }

  List<Song> getCurrentQueue() {
    final sequence = _player.sequenceState?.effectiveSequence;
    if (sequence == null) return [];
    return sequence
        .map((item) => _mediaItemToSong(item.tag as MediaItem))
        .toList();
  }

  Song? getCurrentSong() {
    final item = _player.sequenceState?.currentSource?.tag;
    if (item == null) return null;
    return _mediaItemToSong(item as MediaItem);
  }

  AudioSource buildAudioSource(Song song, String? token) {
    final uri = playbackUriFor(song, token, _resolver);

    return AudioSource.uri(
      uri,
      tag: MediaItem(
        id: song.id,
        title: song.title,
        artist: song.artistName,
        album: song.albumTitle,
        artUri: Uri.parse(song.artworkUrl),
        duration: song.duration,
        extras: {
          'region': song.region,
          'genre': song.genre,
          'localPath': song.localPath,
          'audioUrl': song.audioUrl,
          'artworkUrl': song.artworkUrl,
        },
      ),
    );
  }

  Song _mediaItemToSong(MediaItem item) {
    return Song(
      id: item.id,
      title: item.title,
      artistId: '',
      artistName: item.artist ?? '',
      albumId: '',
      albumTitle: item.album ?? '',
      audioUrl: item.extras?['audioUrl'] as String? ?? '',
      artworkUrl: item.extras?['artworkUrl'] as String? ?? '',
      duration: item.duration ?? Duration.zero,
      region: item.extras?['region'] as String? ?? '',
      language: '',
      genre: item.extras?['genre'] as String? ?? '',
      releaseYear: 0,
      playCount: 0,
      tags: const [],
      isApproved: true,
      isDownloadable: true,
      localPath: item.extras?['localPath'] as String?,
    );
  }

  Future<void> dispose() => _player.dispose();
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService(mediaToken: ref.watch(mediaTokenProvider));
  ref.onDispose(service.dispose);
  return service;
});
