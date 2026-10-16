import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/services/audio_player_service.dart';
import '../../../domain/models/song.dart';
import '../providers/player_providers.dart';

/// Spotify-style tap behavior: start playback and immediately slide the Full
/// Player up. Playback loading continues while the player screen animates in
/// (the screen shows the track as soon as the queue is set).
///
/// Every song-tile tap in the app should go through this instead of calling
/// [PlayerController.playSong] directly. Pass the full list the song belongs
/// to as [queue] (not just the cards on screen) and, for a Home/See All
/// collection, its [source] so playback continues past that list.
void playSongAndOpenPlayer(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  List<Song>? queue,
  int? queueIndex,
  QueueSource? source,
}) {
  // Fire-and-forget: AudioPlayerService handles and logs load failures
  // itself; anything else is logged rather than reported as an uncaught
  // (Crashlytics-fatal) error.
  ref
      .read(playerControllerProvider)
      .playSong(song, queue: queue, queueIndex: queueIndex, source: source)
      .catchError(_logPlaybackError);
  context.push('/player');
}

/// Same as [playSongAndOpenPlayer] for the "Continue Listening" rail: resumes
/// at [start] and opens the Full Player.
void resumeSongAndOpenPlayer(
  BuildContext context,
  WidgetRef ref,
  Song song,
  Duration start, {
  List<Song>? queue,
  QueueSource? source,
}) {
  ref
      .read(playerControllerProvider)
      .playSongAt(song, start, queue: queue, source: source)
      .catchError(_logPlaybackError);
  context.push('/player');
}

void _logPlaybackError(Object e, StackTrace st) =>
    debugPrint('[AUDIO] PLAYBACK_ERROR request failed: $e\n$st');
