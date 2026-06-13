import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/song.dart';
import '../../../home/presentation/widgets/shimmer_loading.dart';
import '../../../home/providers/home_providers.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../../../player/providers/player_providers.dart';

final _categorySongsProvider =
    FutureProvider.family<List<Song>, String>((ref, genre) {
  return ref.watch(songDatasourceProvider).getSongsByGenre(genre);
});

class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(_categorySongsProvider(categoryId));

    return Scaffold(
      appBar: AppBar(title: Text(categoryId)),
      body: songsAsync.when(
        loading: () => const ShimmerSongList(),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Failed to load category'),
              TextButton(
                onPressed: () =>
                    ref.invalidate(_categorySongsProvider(categoryId)),
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
                  const Icon(Icons.music_off_rounded,
                      size: 64, color: AppColors.textSecondaryDark),
                  const SizedBox(height: 16),
                  Text('No $categoryId songs yet',
                      style: Theme.of(context).textTheme.titleMedium),
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
    );
  }
}
