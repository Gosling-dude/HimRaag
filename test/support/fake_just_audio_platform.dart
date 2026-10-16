import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// A just_audio platform for unit tests: it plays nothing, but answers the
/// real just_audio Dart layer the way the native players do — loading a queue
/// (optionally failing for chosen URLs), seeking, play/pause, queue inserts and
/// the shuffle order the Dart side sends — and lets a test end the current
/// track the way a native player does when a song finishes.
///
/// Everything above the platform boundary (sequence, shuffle indices, current
/// index, error → deactivation) is the actual just_audio code. What this can't
/// show is real decoding, buffering or audio output.
class FakeJustAudioPlatform extends JustAudioPlatform {
  /// URLs that fail to load, like an unreachable or deleted stream.
  final Set<String> failingUrls = {};

  /// Drop mid-queue errors instead of reporting them — what
  /// just_audio_background does — so only the stalled state remains.
  bool swallowErrors = false;

  /// Every load request, in order (a reload after a failure is another one).
  final List<LoadRequest> loads = [];

  FakeAudioPlayer? _player;

  /// The active native player (just_audio recreates it after deactivating it,
  /// e.g. following an error).
  FakeAudioPlayer get player => _player!;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    return _player = FakeAudioPlayer(request.id, this);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    await _player?.dispose(DisposeRequest());
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    await _player?.dispose(DisposeRequest());
    return DisposeAllPlayersResponse();
  }
}

class FakeAudioPlayer extends AudioPlayerPlatform {
  FakeAudioPlayer(super.id, this._platform);

  static const trackDuration = Duration(minutes: 3);

  final FakeJustAudioPlatform _platform;
  final _events = StreamController<PlaybackEventMessage>.broadcast();

  /// Queue URLs in source order.
  final List<String> urls = [];
  List<int> shuffleOrder = [];
  bool shuffleMode = false;
  LoopModeMessage loopMode = LoopModeMessage.off;
  int index = 0;
  Duration position = Duration.zero;
  ProcessingStateMessage state = ProcessingStateMessage.idle;
  bool playing = false;
  Completer<void>? _playing;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  List<int> get _order =>
      shuffleMode ? shuffleOrder : List.generate(urls.length, (i) => i);

  /// Ends the current track as a native player does at a natural song end:
  /// moves to the next item in play order (honouring shuffle and loop mode),
  /// or completes the queue.
  void finishTrack() {
    position = Duration.zero;
    if (loopMode == LoopModeMessage.one) {
      _emit(state);
      return;
    }
    final order = _order;
    final next = order.indexOf(index) + 1;
    if (next < order.length || loopMode == LoopModeMessage.all) {
      _moveTo(order[next % order.length]);
    } else {
      position = trackDuration;
      _stopPlaying();
      _emit(ProcessingStateMessage.completed);
    }
  }

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    _platform.loads.add(request);
    final source = request.audioSourceMessage as ConcatenatingAudioSourceMessage;
    urls
      ..clear()
      ..addAll(source.children.map((c) => (c as UriAudioSourceMessage).uri));
    shuffleOrder = List.of(source.shuffleOrder);
    index = request.initialIndex ?? 0;
    position = request.initialPosition ?? Duration.zero;
    _emit(ProcessingStateMessage.loading);
    if (_platform.failingUrls.contains(urls[index])) {
      // Native players answer a failed prepare with an error result.
      throw PlatformException(
          code: '404', message: 'Unable to load', details: {'index': index});
    }
    _emit(ProcessingStateMessage.ready);
    return LoadResponse(duration: trackDuration);
  }

  /// Like the native players, completes only when playback stops.
  @override
  Future<PlayResponse> play(PlayRequest request) async {
    playing = true;
    _emit(state);
    await (_playing ??= Completer<void>()).future;
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _stopPlaying();
    _emit(state);
    return PauseResponse();
  }

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    position = request.position ?? Duration.zero;
    if (request.index != null && request.index != index) {
      _moveTo(request.index!);
    } else {
      _emit(state);
    }
    return SeekResponse();
  }

  /// Moving onto a failing item reports the new index, then an error for it,
  /// and stays there — the case where the native player does not skip it on
  /// its own (iOS's last item, ExoPlayer after its 5-error budget).
  void _moveTo(int newIndex) {
    index = newIndex;
    if (_platform.failingUrls.contains(urls[index])) {
      _emit(ProcessingStateMessage.buffering);
      if (!_platform.swallowErrors) {
        _events.addError(PlatformException(
            code: '404', message: 'Unable to load', details: {'index': index}));
      }
      return;
    }
    _emit(ProcessingStateMessage.ready);
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
      SetShuffleModeRequest request) async {
    shuffleMode = request.shuffleMode == ShuffleModeMessage.all;
    return SetShuffleModeResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
      SetShuffleOrderRequest request) async {
    final source = request.audioSourceMessage as ConcatenatingAudioSourceMessage;
    shuffleOrder = List.of(source.shuffleOrder);
    return SetShuffleOrderResponse();
  }

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    loopMode = request.loopMode;
    return SetLoopModeResponse();
  }

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
      ConcatenatingInsertAllRequest request) async {
    urls.insertAll(request.index,
        request.children.map((c) => (c as UriAudioSourceMessage).uri));
    if (index >= request.index) index += request.children.length;
    shuffleOrder = List.of(request.shuffleOrder);
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
      ConcatenatingRemoveRangeRequest request) async {
    urls.removeRange(request.startIndex, request.endIndex);
    if (index >= request.endIndex) {
      index -= request.endIndex - request.startIndex;
    }
    shuffleOrder = List.of(request.shuffleOrder);
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse();

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
          SetSkipSilenceRequest request) async =>
      SetSkipSilenceResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    _stopPlaying();
    return DisposeResponse();
  }

  void _stopPlaying() {
    playing = false;
    _playing?.complete();
    _playing = null;
  }

  void _emit(ProcessingStateMessage newState) {
    state = newState;
    if (_events.isClosed) return;
    _events.add(PlaybackEventMessage(
      processingState: newState,
      updateTime: DateTime.now(),
      updatePosition: position,
      bufferedPosition: position,
      duration: trackDuration,
      icyMetadata: null,
      currentIndex: index,
      androidAudioSessionId: null,
    ));
  }
}
