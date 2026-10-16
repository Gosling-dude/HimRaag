import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/audio_player_service.dart';
import '../../../home/presentation/widgets/shimmer_loading.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../../../player/presentation/player_navigation.dart';
import '../../../player/providers/player_providers.dart';
import '../../providers/song_collection_providers.dart';

/// The "See All" page for a Home collection (Made for You, Trending, New
/// Releases, a region): every song in it, loaded page by page as the list
/// scrolls. Playing from here queues the whole collection, which keeps
/// growing from it as playback advances.
class SongCollectionScreen extends ConsumerWidget {
  const SongCollectionScreen({super.key, required this.collection});

  final SongCollection collection;

  bool get _isRegion => collection.kind == SongCollectionKind.region;

  Color get _accent => _isRegion
      ? AppColors.regionColors[collection.region] ?? AppColors.primary
      : AppColors.primary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(songCollectionProvider(collection));

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.title),
        backgroundColor: _isRegion ? _accent.withValues(alpha: 0.2) : null,
      ),
      body: Container(
        decoration: _isRegion
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [_accent.withValues(alpha: 0.1), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                ),
              )
            : null,
        child: _buildBody(context, ref, state),
      ),
    );
  }

  Widget _buildBody(
      BuildContext context, WidgetRef ref, SongCollectionState state) {
    if (state.songs.isEmpty) {
      if (state.isLoading) return const ShimmerSongList();
      if (state.error != null) {
        return _Message(
          icon: Icons.wifi_off_rounded,
          title: 'Could not load ${collection.title}',
          action: TextButton(
            onPressed: () =>
                ref.invalidate(songCollectionSeedProvider(collection)),
            child: const Text('Retry'),
          ),
        );
      }
      return _Message(
        icon: _isRegion ? Icons.landscape_rounded : Icons.music_off_rounded,
        iconColor: _accent.withValues(alpha: 0.5),
        title: _isRegion
            ? 'No ${collection.region} songs yet'
            : 'No songs here yet',
        subtitle: 'Check back soon!',
      );
    }

    final songs = state.songs;
    final controller = ref.read(songCollectionProvider(collection).notifier);
    final player = ref.read(playerControllerProvider);
    QueueSource source() =>
        ref.read(songCollectionQueueSourceProvider(collection));

    void play(int index) => playSongAndOpenPlayer(
          context,
          ref,
          songs[index],
          queue: songs,
          queueIndex: index,
          source: source(),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => player.playAll(songs, source: source()),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Play'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  // Shuffle needs at least two songs to mean anything.
                  onPressed: songs.length < 2
                      ? null
                      : () => player.shufflePlay(songs, source: source()),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Shuffle'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${songs.length}${state.hasMore ? '+' : ''} '
              'song${songs.length == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: songs.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < songs.length) {
                return SongListTile(
                  song: songs[index],
                  showIndex: true,
                  index: index + 1,
                  onTap: () => play(index),
                );
              }
              if (state.error != null && !state.isLoading) {
                return _LoadMoreError(onRetry: controller.loadMore);
              }
              // Built as it scrolls into view — and right away when the list
              // is shorter than the screen — which is what loads the next page.
              return _LoadMoreTrigger(onVisible: controller.loadMore);
            },
          ),
        ),
      ],
    );
  }
}

/// Requests the next page once, when first built.
class _LoadMoreTrigger extends StatefulWidget {
  const _LoadMoreTrigger({required this.onVisible});

  final Future<void> Function() onVisible;

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisible();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _LoadMoreError extends StatelessWidget {
  const _LoadMoreError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppColors.textSecondaryDark, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load more songs',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.iconColor = AppColors.textSecondaryDark,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
          ],
          if (action != null) action!,
        ],
      ),
    );
  }
}
