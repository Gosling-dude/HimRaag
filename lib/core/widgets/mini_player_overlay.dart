import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/player/presentation/widgets/mini_player.dart';
import '../../features/player/providers/player_providers.dart';

/// Floats the global [MiniPlayer] over full-screen routes that live outside
/// the bottom-nav shell (album/artist/category/region/playlist/all-songs/
/// profile). Screens inside [MainShell] get the mini player from the shell
/// itself; wrapping a route with this keeps playback visible everywhere,
/// Spotify-style, without touching the screens' own layouts.
class MiniPlayerOverlay extends ConsumerWidget {
  const MiniPlayerOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCurrentSong = ref.watch(currentSongProvider) != null;

    return Stack(
      children: [
        child,
        if (hasCurrentSong)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: MiniPlayer(),
            ),
          ),
      ],
    );
  }
}
