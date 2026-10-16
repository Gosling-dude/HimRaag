import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../domain/models/song.dart';

enum RepeatMode { off, one, all }

/// Where a playback queue came from, so the player can keep extending it past
/// the songs that were loaded when playback started (the five Home banner
/// slides, the first page of a See All list, …).
abstract class QueueSource {
  /// Every song currently known for this context, in play order.
  List<Song> get songs;

  /// Whether [loadMore] may still find songs that are not in [songs].
  bool get hasMore;

  /// Fetches the next page (a no-op once exhausted) and returns [songs].
  Future<List<Song>> loadMore();
}

class AudioPlayerService {
  AudioPlayerService({
    AudioPlayer? player,
    this.failureGracePeriod = const Duration(seconds: 2),
    this.stallTimeout = const Duration(seconds: 30),
  }) : _player = player ?? AudioPlayer() {
    // Surface engine-level state + errors. Without this, a failed load (e.g. a
    // broken audio platform or an unreachable URL) is invisible: the future
    // throws into a fire-and-forget call site and is swallowed.
    _subscriptions.add(_player.playerStateStream.listen(
      _onPlayerState,
      onError: (Object e, StackTrace st) =>
          debugPrint('[AUDIO] PLAYBACK_ERROR (stateStream): $e\n$st'),
    ));
    _subscriptions.add(_player.playbackEventStream.listen(
      (_) {},
      onError: _onPlaybackError,
    ));
    _subscriptions.add(_player.currentIndexStream.listen((_) => _onTrackChanged()));
  }

  /// When this few songs are left after the current one (in play order), the
  /// queue asks its [QueueSource] for more, so the next song is queued before
  /// the current one ends.
  static const int expandThreshold = 3;

  /// Tracks allowed to fail back to back before playback pauses instead of
  /// skipping again (e.g. the device went offline mid-queue).
  static const int maxConsecutiveFailures = 5;

  /// How long a failed or idle track is left for the native player to recover
  /// (both ExoPlayer and AVQueuePlayer skip some failed items themselves)
  /// before the queue skips it.
  final Duration failureGracePeriod;

  /// How long playback may sit loading/buffering before the track is treated
  /// as failed. just_audio_background swallows platform errors, so a stall is
  /// the only signal some failures leave.
  final Duration stallTimeout;

  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final _trackStarted = StreamController<Song>.broadcast();

  ConcatenatingAudioSource? _playlist;
  QueueSource? _source;

  /// Every id enqueued in the current queue — including songs the user removed
  /// — so expansion never adds a duplicate or brings a removed song back.
  final Set<String> _queuedIds = {};

  /// Bumped whenever the queue is replaced; async work started for an older
  /// queue (page loads, failure checks) compares it and drops stale results.
  int _generation = 0;
  int? _expandingFor;
  int _consecutiveFailures = 0;
  Timer? _failureTimer;
  String? _lastStartedKey;

  AudioPlayer get player => _player;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<double> get volumeStream => _player.volumeStream;
  Stream<SequenceState?> get sequenceStateStream => _player.sequenceStateStream;
  Stream<bool> get shuffleModeEnabledStream => _player.shuffleModeEnabledStream;
  Stream<RepeatMode> get repeatModeStream =>
      _player.loopModeStream.map(_repeatModeFor);

  /// Emits each queue item once it is actually playing (loaded and audible),
  /// including tracks the queue advanced to on its own. Failed loads never
  /// emit, so play history only counts real playback.
  Stream<Song> get trackStartedStream => _trackStarted.stream;

  bool get isPlaying => _player.playing;
  bool get shuffleModeEnabled => _player.shuffleModeEnabled;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  int? get currentIndex => _player.currentIndex;

  /// Position of the current song in [getCurrentQueue] (play order).
  int? get currentQueuePosition {
    final order = _player.effectiveIndices;
    final index = _player.currentIndex;
    if (order == null || index == null) return null;
    final position = order.indexOf(index);
    return position < 0 ? null : position;
  }

  Future<void> playSong(Song song, {List<Song>? queue, int? queueIndex}) {
    final songs = queue ?? [song];
    return playQueue(songs, index: queueIndex ?? 0);
  }

  /// Replaces the queue with [songs] and starts playing `songs[index]`.
  ///
  /// Duplicate ids and songs without a playable URL are dropped (the start
  /// follows the selected song). With a [source] the queue keeps growing from
  /// it as playback nears the end, so it never stops at the edge of the songs
  /// that happened to be loaded on screen. [shuffle], when given, sets shuffle
  /// mode for the new queue; the selected song always plays first.
  Future<void> playQueue(
    List<Song> songs, {
    int index = 0,
    Duration? initialPosition,
    QueueSource? source,
    bool? shuffle,
  }) async {
    if (songs.isEmpty) return;
    final selected = songs[index.clamp(0, songs.length - 1)];
    final ids = <String>{};
    final queue = [
      for (final s in songs)
        if (_isPlayable(s) && ids.add(s.id)) s,
    ];
    final start = queue.indexWhere((s) => s.id == selected.id);

    debugPrint(
      '[AUDIO] PLAY_REQUEST id=${selected.id} title="${selected.title}" '
      'queueLength=${queue.length} index=$start '
      'source=${source?.runtimeType ?? 'none'}',
    );
    debugPrint('[AUDIO] AUDIO_URL ${selected.isDownloaded ? selected.localPath : selected.audioUrl}');

    if (start < 0) {
      debugPrint('[AUDIO] PLAYBACK_ERROR invalid/empty audioUrl: "${selected.audioUrl}"');
      return;
    }

    final generation = ++_generation;
    _failureTimer?.cancel();
    _consecutiveFailures = 0;
    _source = source;
    _queuedIds
      ..clear()
      ..addAll(ids);
    final playlist = _playlist = ConcatenatingAudioSource(
      children: queue.map(_buildAudioSource).toList(),
      shuffleOrder: UpcomingShuffleOrder(() => _player.currentIndex),
    );
    if (shuffle != null) {
      try {
        await _player.setShuffleModeEnabled(shuffle);
      } catch (e, st) {
        // Play the queue anyway, in whatever order the player is in.
        debugPrint('[AUDIO] PLAYBACK_ERROR setShuffleModeEnabled: $e\n$st');
      }
    }
    await _load(generation, playlist, start, initialPosition);
    // A queue that starts at the same index as the previous one emits no
    // index change, so check here whether it is already short.
    if (generation == _generation && _isRunningLow) {
      unawaited(_expand(generation));
    }
  }

  /// Loads [playlist] at [index] and starts playback. Also the recovery path
  /// after a failed track: re-setting the source reactivates a player that
  /// just_audio deactivated on error and resets the native error budget.
  Future<void> _load(
    int generation,
    ConcatenatingAudioSource playlist,
    int index,
    Duration? position,
  ) async {
    try {
      debugPrint('[AUDIO] SET_AUDIO_SOURCE initialIndex=$index');
      // A broken audio platform makes setAudioSource hang forever (no error,
      // no duration). Time-box it so the failure becomes a visible error
      // instead of a silent freeze.
      final duration = await _player
          .setAudioSource(
            playlist,
            initialIndex: index,
            initialPosition: position,
            preload: true,
          )
          .timeout(const Duration(seconds: 20));
      if (generation != _generation) return;
      debugPrint('[AUDIO] SONG_LOADED duration=$duration');
      _startPlayback();
    } on PlayerInterruptedException {
      // Superseded by a newer queue; nothing to recover.
    } catch (e, st) {
      if (generation != _generation) return;
      debugPrint('[AUDIO] PLAYBACK_ERROR load failed at index $index: $e\n$st');
      await _onTrackFailed(generation, index);
    }
  }

  /// `play()` completes only when playback pauses or ends, so it's never
  /// awaited; errors are logged instead of escaping as uncaught.
  void _startPlayback() {
    if (_player.playing) return;
    _player.play().catchError((Object e, StackTrace st) {
      debugPrint('[AUDIO] PLAYBACK_ERROR play failed: $e\n$st');
    });
  }

  Future<void> playFromQueue(int position) async {
    final index = _sourceIndexAt(position);
    if (index == null) return;
    await _player.seek(Duration.zero, index: index);
    _startPlayback();
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
    // Reshuffles the whole queue — every song, not just the visible ones —
    // with the current song first.
    if (enabled) await _player.shuffle();
  }

  Future<void> addToQueue(Song song) async {
    final playlist = _playlist;
    if (playlist == null || !_isPlayable(song)) return;
    _queuedIds.add(song.id);
    await playlist.add(_buildAudioSource(song));
  }

  Future<void> addToQueueNext(Song song) async {
    final playlist = _playlist;
    if (playlist == null || !_isPlayable(song)) return;
    _queuedIds.add(song.id);
    final nextIndex = (_player.currentIndex ?? 0) + 1;
    await playlist.insert(nextIndex, _buildAudioSource(song));
  }

  /// Removes the song at [position] in the queue as shown (play order).
  Future<void> removeFromQueue(int position) async {
    final playlist = _playlist;
    final index = _sourceIndexAt(position);
    if (playlist == null || index == null) return;
    await playlist.removeAt(index);
  }

  /// The queue in play order (shuffled order while shuffle is on).
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

  // ── Queue growth ──────────────────────────────────────────────────────────

  void _onTrackChanged() {
    final state = _player.playerState;
    // A gapless advance keeps PlayerState at ready/playing, so the new track
    // is only visible here.
    if (state.processingState == ProcessingState.ready && state.playing) {
      _onTrackPlaying();
    }
    if (_isRunningLow) unawaited(_expand(_generation));
  }

  /// Whether few enough songs follow the current one (in play order) to fetch
  /// more. False while that is unknown: setAudioSource announces the new index
  /// before the new sequence, and reading that gap as "nothing left" would
  /// fetch a page for every queue the moment it starts.
  bool get _isRunningLow {
    final position = currentQueuePosition;
    final order = _player.effectiveIndices;
    if (position == null || order == null) return false;
    return order.length - position - 1 <= expandThreshold;
  }

  /// Appends songs from the queue's [QueueSource] that aren't queued yet:
  /// first ones it already holds (e.g. pages a See All list loaded), then a
  /// newly fetched page. Returns whether anything was added.
  Future<bool> _expand(int generation) async {
    final source = _source;
    final playlist = _playlist;
    if (source == null || playlist == null || _expandingFor == generation) {
      return false;
    }
    _expandingFor = generation;
    try {
      var fresh = _unqueued(source.songs);
      if (fresh.isEmpty && source.hasMore) {
        fresh = _unqueued(await source.loadMore());
      }
      // The user may have started a different queue while the page loaded.
      if (generation != _generation || fresh.isEmpty) return false;

      _queuedIds.addAll(fresh.map((s) => s.id));
      final reachedEnd =
          _player.processingState == ProcessingState.completed;
      debugPrint('[AUDIO] QUEUE_EXPANDED +${fresh.length} '
          '(total ${playlist.length + fresh.length})');
      await playlist.addAll(fresh.map(_buildAudioSource).toList());

      // Playback ran off the old end while the page was loading: carry on.
      final current = _player.currentIndex;
      final next = current == null ? null : _indexAfter(current);
      if (reachedEnd && next != null && generation == _generation) {
        await _player.seek(Duration.zero, index: next);
        _startPlayback();
      }
      return true;
    } catch (e, st) {
      debugPrint('[AUDIO] QUEUE_EXPAND_FAILED: $e\n$st');
      return false;
    } finally {
      if (_expandingFor == generation) _expandingFor = null;
    }
  }

  List<Song> _unqueued(List<Song> songs) {
    final seen = <String>{};
    return [
      for (final s in songs)
        if (_isPlayable(s) && !_queuedIds.contains(s.id) && seen.add(s.id)) s,
    ];
  }

  // ── Failure handling ──────────────────────────────────────────────────────

  void _onPlayerState(PlayerState state) {
    debugPrint(
      '[AUDIO] PLAYER_STATE processing=${state.processingState} '
      'playing=${state.playing}',
    );
    final watching = state.playing && _playlist != null;
    switch (state.processingState) {
      case ProcessingState.ready:
        _failureTimer?.cancel();
        if (state.playing) _onTrackPlaying();
      case ProcessingState.idle when watching:
        // just_audio deactivates the platform after an error while `playing`
        // stays true: the user still wants audio but nothing is loaded.
        _watchForFailure(failureGracePeriod);
      case ProcessingState.loading || ProcessingState.buffering when watching:
        _watchForFailure(stallTimeout);
      case ProcessingState.completed:
        _failureTimer?.cancel();
        // The end of the loaded queue — pick up anything an earlier page load
        // missed (e.g. it failed while offline) and carry on.
        unawaited(_expand(_generation));
      default:
        _failureTimer?.cancel();
    }
  }

  void _onPlaybackError(Object e, StackTrace st) {
    debugPrint('[AUDIO] PLAYBACK_ERROR (eventStream): $e\n$st');
    // 'abort' is a load we interrupted ourselves (a new queue or a reload).
    if (e is PlatformException && e.code == 'abort') return;
    final details = e is PlatformException ? e.details : null;
    final failed = details is Map ? details['index'] as int? : null;
    // Native players usually skip a failed item on their own; step in only if
    // playback is still on it once the grace period is over. (iOS also reports
    // failures of items that aren't current — those are skipped natively when
    // reached, and the index check below leaves them alone.)
    _watchForFailure(failureGracePeriod, index: failed, anyState: failed != null);
  }

  /// Treats the track at [index] (default: the current one) as failed if,
  /// after [delay], playback is still on it and not playing — or, with
  /// [anyState], still on it at all.
  void _watchForFailure(Duration delay, {int? index, bool anyState = false}) {
    final generation = _generation;
    final watched = index ?? _player.currentIndex;
    if (watched == null) return;
    _failureTimer?.cancel();
    _failureTimer = Timer(delay, () {
      final state = _player.playerState;
      final stuck = anyState ||
          (state.playing &&
              state.processingState != ProcessingState.ready &&
              state.processingState != ProcessingState.completed);
      if (stuck && _player.currentIndex == watched) {
        unawaited(_onTrackFailed(generation, watched));
      }
    });
  }

  /// Skips past a track that could not be played. Bounded by
  /// [maxConsecutiveFailures] so a device that went offline pauses (keeping
  /// the queue and position) instead of spinning through the whole queue.
  Future<void> _onTrackFailed(int generation, int failedIndex) async {
    final playlist = _playlist;
    if (generation != _generation || playlist == null) return;
    _failureTimer?.cancel();
    if (++_consecutiveFailures > maxConsecutiveFailures) {
      debugPrint('[AUDIO] PLAYBACK_ERROR $maxConsecutiveFailures tracks failed '
          'in a row — pausing');
      await _player.pause();
      return;
    }
    var next = _indexAfter(failedIndex);
    if (next == null && await _expand(generation)) {
      next = _indexAfter(failedIndex);
    }
    if (generation != _generation) return;
    if (next == null) {
      debugPrint('[AUDIO] PLAYBACK_ERROR last track in the queue failed');
      await _player.pause();
      return;
    }
    debugPrint('[AUDIO] SKIP_FAILED index=$failedIndex → $next');
    await _load(generation, playlist, next, null);
  }

  void _onTrackPlaying() {
    _consecutiveFailures = 0;
    final index = _player.currentIndex;
    if (index == null) return;
    final key = '$_generation:$index';
    if (key == _lastStartedKey) return;
    _lastStartedKey = key;
    final song = getCurrentSong();
    if (song != null) _trackStarted.add(song);
  }

  /// The source index played after [index] (shuffle- and repeat-aware).
  int? _indexAfter(int index) {
    final order = _player.effectiveIndices;
    if (order == null || order.isEmpty) return null;
    final position = order.indexOf(index);
    if (position < 0) return null;
    if (position + 1 < order.length) return order[position + 1];
    return _player.loopMode == LoopMode.all ? order.first : null;
  }

  int? _sourceIndexAt(int position) {
    final order = _player.effectiveIndices;
    if (order == null || position < 0 || position >= order.length) return null;
    return order[position];
  }

  bool _isPlayable(Song song) =>
      song.isDownloaded ||
      (song.audioUrl.isNotEmpty && Uri.tryParse(song.audioUrl) != null);

  static RepeatMode _repeatModeFor(LoopMode mode) => switch (mode) {
        LoopMode.off => RepeatMode.off,
        LoopMode.one => RepeatMode.one,
        LoopMode.all => RepeatMode.all,
      };

  AudioSource _buildAudioSource(Song song) {
    final uri = song.isDownloaded
        ? Uri.file(song.localPath!)
        : Uri.parse(song.audioUrl);

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

  Future<void> dispose() async {
    _failureTimer?.cancel();
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    await _trackStarted.close();
    await _player.dispose();
  }
}

/// [DefaultShuffleOrder] puts newly added songs at random positions anywhere
/// in the play order — including *before* the current song, where they would
/// never be reached. Queues here grow mid-playback (paging in more of a
/// collection), so new songs go to random positions after the current one.
class UpcomingShuffleOrder extends ShuffleOrder {
  UpcomingShuffleOrder(this._currentIndex, {Random? random})
      : _random = random ?? Random(),
        _initial = DefaultShuffleOrder(random: random);

  final int? Function() _currentIndex;
  final Random _random;

  // Shuffling and removal behave exactly like the default order.
  final DefaultShuffleOrder _initial;

  @override
  List<int> get indices => _initial.indices;

  @override
  void shuffle({int? initialIndex}) => _initial.shuffle(initialIndex: initialIndex);

  @override
  void insert(int index, int count) {
    final current = _currentIndex();
    for (var i = 0; i < indices.length; i++) {
      if (indices[i] >= index) indices[i] += count;
    }
    // Before the first load the player's index belongs to the previous queue,
    // and nothing has played yet, so anywhere is "upcoming".
    var after = -1;
    if (current != null && indices.isNotEmpty) {
      after = indices.indexOf(current >= index ? current + count : current);
    }
    for (var newIndex = index; newIndex < index + count; newIndex++) {
      final position = after + 1 + _random.nextInt(indices.length - after);
      indices.insert(position, newIndex);
    }
  }

  @override
  void removeRange(int start, int end) => _initial.removeRange(start, end);

  @override
  void clear() => _initial.clear();
}

final audioPlayerServiceProvider = Provider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();
  ref.onDispose(service.dispose);
  return service;
});
