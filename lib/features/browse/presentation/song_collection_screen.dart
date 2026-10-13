import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/models/song.dart';
import '../../home/presentation/widgets/shimmer_loading.dart';
import '../../library/presentation/widgets/song_list_tile.dart';
import '../../player/providers/player_providers.dart';

/// A full-page song list with Play / Shuffle — the target of Home's
/// "See All" for song rows (Trending, New Releases, Recommended, festivals).
class SongCollectionScreen extends ConsumerWidget {
  const SongCollectionScreen({
    super.key,
    required this.title,
    required this.songs,
    required this.onRetry,
    this.subtitle,
    this.icon = Icons.queue_music_rounded,
    this.emptyMessage = 'No songs here yet.',
    this.notice,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final AsyncValue<List<Song>> songs;
  final VoidCallback onRetry;
  final String emptyMessage;

  /// Optional note shown above the list (e.g. why a fallback is shown).
  final String? notice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: songs.when(
        loading: () => const ShimmerSongList(),
        error: (_, __) => _Message(
          icon: Icons.wifi_off_rounded,
          text: 'Failed to load songs',
          action: TextButton(onPressed: onRetry, child: const Text('Retry')),
        ),
        data: (list) {
          if (list.isEmpty) return _Message(icon: icon, text: emptyMessage);
          final player = ref.read(playerControllerProvider);
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: list.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _Header(
                  icon: icon,
                  subtitle: subtitle,
                  notice: notice,
                  count: list.length,
                  onPlay: () => player.playSong(list.first, queue: list),
                  onShuffle: () {
                    final shuffled = [...list]..shuffle();
                    player.playSong(shuffled.first, queue: shuffled);
                  },
                );
              }
              final song = list[i - 1];
              return SongListTile(
                song: song,
                onTap: () =>
                    player.playSong(song, queue: list, queueIndex: i - 1),
              );
            },
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.count,
    required this.onPlay,
    required this.onShuffle,
    this.subtitle,
    this.notice,
  });

  final IconData icon;
  final int count;
  final String? subtitle;
  final String? notice;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [if (subtitle != null) subtitle!, '$count songs'].join(' · '),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondaryDark),
              ),
            ),
          ]),
          if (notice != null) ...[
            const SizedBox(height: 8),
            Text(notice!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondaryDark)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShuffle,
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textSecondaryDark),
          const SizedBox(height: 12),
          Text(text, style: Theme.of(context).textTheme.titleMedium),
          if (action != null) action!,
        ],
      ),
    );
  }
}
