import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/models/song.dart';
import '../providers/player_providers.dart';

/// Spotify-style tap behavior: start playback and immediately slide the Full
/// Player up. Playback loading continues while the player screen animates in
/// (the screen shows the track as soon as the queue is set).
///
/// Every song-tile tap in the app should go through this instead of calling
/// [PlayerController.playSong] directly.
void playSongAndOpenPlayer(
  BuildContext context,
  WidgetRef ref,
  Song song, {
  List<Song>? queue,
  int? queueIndex,
}) {
  // Fire-and-forget, same as the previous call sites — errors are logged and
  // surfaced inside AudioPlayerService.
  ref
      .read(playerControllerProvider)
      .playSong(song, queue: queue, queueIndex: queueIndex);
  context.push('/player');
}

/// Same as [playSongAndOpenPlayer] for the "Continue Listening" rail: resumes
/// at [start] and opens the Full Player.
void resumeSongAndOpenPlayer(
  BuildContext context,
  WidgetRef ref,
  Song song,
  Duration start,
) {
  ref.read(playerControllerProvider).playSongAt(song, start);
  context.push('/player');
}
