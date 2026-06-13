import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/audio_player_service.dart';
import '../../../../domain/models/song.dart';
import '../../../library/providers/library_providers.dart';
import '../../providers/player_providers.dart';
import '../widgets/lyrics_view.dart';
import '../widgets/queue_view.dart';

class FullPlayerScreen extends ConsumerStatefulWidget {
  const FullPlayerScreen({super.key});

  @override
  ConsumerState<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends ConsumerState<FullPlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = ref.watch(currentSongProvider);
    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No song playing')),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, song),
      body: Stack(
        children: [
          _BlurredBackground(artworkUrl: song.artworkUrl),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, song),
                Expanded(
                  child: _showLyrics
                      ? LyricsView(lyrics: song.lyrics)
                      : _PlayerControls(song: song),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Song song) {
    return AppBar(
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
        color: Colors.white,
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showLyrics ? Icons.music_note_rounded : Icons.lyrics_outlined,
            color: Colors.white,
          ),
          onPressed: () => setState(() => _showLyrics = !_showLyrics),
        ),
        IconButton(
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white),
          onPressed: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const QueueView(),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Song song) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 24, right: 24, bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              song.region,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          _FavoriteButton(songId: song.id),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () => _showSongOptions(context, song),
          ),
        ],
      ),
    );
  }

  void _showSongOptions(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SongOptionsSheet(song: song),
    );
  }
}

class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({required this.artworkUrl});

  final String artworkUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: artworkUrl,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                Container(color: AppColors.backgroundDark),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerControls extends ConsumerStatefulWidget {
  const _PlayerControls({required this.song});

  final Song song;

  @override
  ConsumerState<_PlayerControls> createState() => _PlayerControlsState();
}

class _PlayerControlsState extends ConsumerState<_PlayerControls> {
  bool _isSeeking = false;
  double _seekValue = 0;

  @override
  Widget build(BuildContext context) {
    final isPlaying = ref.watch(isPlayingProvider);
    final positionAsync = ref.watch(playerPositionProvider);
    final durationAsync = ref.watch(playerDurationProvider);
    final repeatMode = ref.watch(repeatModeProvider);
    final isShuffle = ref.watch(isShuffleProvider);
    final controller = ref.read(playerControllerProvider);

    final position = positionAsync.valueOrNull ?? Duration.zero;
    final duration = durationAsync.valueOrNull ?? Duration.zero;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _ArtworkWidget(artworkUrl: widget.song.artworkUrl),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.song.artistName,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _FavoriteButton(songId: widget.song.id),
            ],
          ),
          const SizedBox(height: 32),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _isSeeking ? _seekValue : progress.clamp(0.0, 1.0),
              onChangeStart: (v) {
                setState(() {
                  _isSeeking = true;
                  _seekValue = v;
                });
              },
              onChanged: (v) => setState(() => _seekValue = v),
              onChangeEnd: (v) {
                _isSeeking = false;
                if (duration > Duration.zero) {
                  controller.seekTo(
                    Duration(
                      milliseconds: (v * duration.inMilliseconds).round(),
                    ),
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  isShuffle ? Icons.shuffle_on_rounded : Icons.shuffle_rounded,
                  color: isShuffle
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.7),
                ),
                iconSize: 28,
                onPressed: controller.toggleShuffle,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded,
                    color: Colors.white),
                iconSize: 40,
                onPressed: controller.skipToPrevious,
              ),
              _PlayPauseButton(
                  isPlaying: isPlaying, onTap: controller.togglePlayPause),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
                iconSize: 40,
                onPressed: controller.skipToNext,
              ),
              IconButton(
                icon: Icon(
                  _repeatIcon(repeatMode),
                  color: repeatMode != RepeatMode.off
                      ? AppColors.accent
                      : Colors.white.withValues(alpha: 0.7),
                ),
                iconSize: 28,
                onPressed: controller.cycleRepeatMode,
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  IconData _repeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return Icons.repeat_rounded;
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
      case RepeatMode.all:
        return Icons.repeat_on_rounded;
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ArtworkWidget extends StatelessWidget {
  const _ArtworkWidget({required this.artworkUrl});

  final String artworkUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: artworkUrl,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            color: AppColors.primary.withValues(alpha: 0.4),
            child: const Icon(Icons.music_note_rounded,
                color: Colors.white, size: 80),
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            key: ValueKey(isPlaying),
            size: 36,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.songId});

  final String songId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(isFavoriteProvider(songId));

    return IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFavorite),
          color: isFavorite
              ? AppColors.error
              : Colors.white.withValues(alpha: 0.7),
          size: 26,
        ),
      ),
      onPressed: () =>
          ref.read(libraryProvider.notifier).toggleFavorite(songId),
    );
  }
}

class _SongOptionsSheet extends ConsumerWidget {
  const _SongOptionsSheet({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(playerControllerProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dividerDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: song.artworkUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        color: AppColors.primary, width: 48, height: 48),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600)),
                      Text(song.artistName,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.dividerDark, height: 24),
          _OptionTile(
            icon: Icons.playlist_add_rounded,
            label: 'Add to Queue',
            onTap: () {
              controller.addToQueue(song);
              Navigator.pop(context);
            },
          ),
          _OptionTile(
            icon: Icons.album_rounded,
            label: 'Go to Album',
            onTap: () {
              Navigator.pop(context);
              context.push('/album/${song.albumId}');
            },
          ),
          _OptionTile(
            icon: Icons.person_rounded,
            label: 'Go to Artist',
            onTap: () {
              Navigator.pop(context);
              context.push('/artist/${song.artistId}');
            },
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white.withValues(alpha: 0.8)),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: onTap,
    );
  }
}
