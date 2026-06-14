import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/download_service.dart';
import '../../../../domain/models/song.dart';
import '../../../home/presentation/widgets/shimmer_loading.dart';
import '../../../home/providers/home_providers.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../../../player/providers/player_providers.dart';

class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final String albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(albumDetailProvider(albumId));
    final songsAsync = ref.watch(albumSongsProvider(albumId));

    return Scaffold(
      body: albumAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Failed to load album'),
              TextButton(
                onPressed: () => ref.invalidate(albumDetailProvider(albumId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (album) {
          if (album == null) {
            return const Center(child: Text('Album not found'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: album.artworkUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                            color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: 80,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              album.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () =>
                                  context.push('/artist/${album.artistId}'),
                              child: Text(
                                album.artistName,
                                style: const TextStyle(
                                    color: AppColors.accent, fontSize: 15),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${album.region} • ${album.releaseYear} • ${album.songCount} songs',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: songsAsync.when(
                  loading: () => const ShimmerSongList(),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Failed to load songs'),
                  ),
                  data: (songs) => Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: songs.isEmpty
                                    ? null
                                    : () => ref
                                        .read(playerControllerProvider)
                                        .playSong(
                                          songs.first,
                                          queue: songs,
                                          queueIndex: 0,
                                        ),
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('Play All'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: songs.isEmpty
                                  ? null
                                  : () => _downloadAll(context, ref, songs),
                              icon: const Icon(Icons.download_rounded),
                              label: const Text('Download All'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...songs.asMap().entries.map(
                            (entry) => SongListTile(
                              song: entry.value,
                              showIndex: true,
                              index: entry.key + 1,
                              onTap: () =>
                                  ref.read(playerControllerProvider).playSong(
                                        entry.value,
                                        queue: songs,
                                        queueIndex: entry.key,
                                      ),
                            ),
                          ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _downloadAll(BuildContext context, WidgetRef ref, List<Song> songs) {
    final downloadService = ref.read(downloadServiceProvider);
    final downloadable = songs
        .where((s) => s.isDownloadable && !downloadService.isDownloaded(s.id))
        .toList();

    if (downloadable.isEmpty) {
      final allDownloaded = songs.every((s) => downloadService.isDownloaded(s.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allDownloaded
                ? 'All songs already downloaded'
                : 'Downloads not available for this album',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    for (final song in downloadable) {
      downloadService.downloadSong(song).listen(
            (_) {},
            onError: (_) {},
            cancelOnError: false,
          );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Downloading ${downloadable.length} song${downloadable.length == 1 ? '' : 's'}…',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
