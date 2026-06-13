import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/widgets/shimmer_loading.dart';
import '../../../home/providers/home_providers.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../../../player/providers/player_providers.dart';

class RegionScreen extends ConsumerWidget {
  const RegionScreen({super.key, required this.regionId});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(regionSongsProvider(regionId));
    final regionColor = AppColors.regionColors[regionId] ?? AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(regionId),
        backgroundColor: regionColor.withValues(alpha: 0.2),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [regionColor.withValues(alpha: 0.1), Colors.transparent],
            begin: Alignment.topCenter,
            end: Alignment.center,
          ),
        ),
        child: songsAsync.when(
          loading: () => const ShimmerSongList(),
          error: (_, __) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 48, color: AppColors.textSecondaryDark),
                const SizedBox(height: 12),
                const Text('Failed to load songs'),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(regionSongsProvider(regionId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (songs) {
            if (songs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.landscape_rounded,
                        size: 64, color: regionColor.withValues(alpha: 0.5)),
                    const SizedBox(height: 16),
                    Text('No $regionId songs yet',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Check back soon!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryDark,
                            )),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: songs.length,
              itemBuilder: (context, index) => SongListTile(
                song: songs[index],
                onTap: () => ref.read(playerControllerProvider).playSong(
                      songs[index],
                      queue: songs,
                      queueIndex: index,
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}
