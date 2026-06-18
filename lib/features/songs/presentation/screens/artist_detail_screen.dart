import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/display/consumer_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../home/presentation/widgets/album_card.dart';
import '../../../home/presentation/widgets/shimmer_loading.dart';
import '../../../home/providers/home_providers.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../../../player/providers/player_providers.dart';

class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistAsync = ref.watch(artistDetailProvider(artistId));
    final songsAsync = ref.watch(artistSongsProvider(artistId));
    final albumsAsync = ref.watch(artistAlbumsProvider(artistId));

    return Scaffold(
      body: artistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load artist')),
        data: (artist) {
          if (artist == null) {
            return const Center(child: Text('Artist not found'));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: artist.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppColors.surfaceDark),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          child: const Icon(Icons.person_rounded,
                              color: AppColors.primary, size: 80),
                        ),
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
                        bottom: 60,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  artist.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (artist.isVerified) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.verified_rounded,
                                      color: AppColors.primary, size: 22),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              artist.monthlyListeners > 0
                                  ? '${artist.displayRegion} • ${_formatListeners(artist.monthlyListeners)} monthly listeners'
                                  : artist.displayRegion,
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
              if (artist.bio.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      artist.bio,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: albumsAsync.when(
                  loading: () => const ShimmerHorizontalList(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (albums) {
                    if (albums.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                          child: Text('Albums',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        SizedBox(
                          height: 190,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: albums.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, index) =>
                                AlbumCard(album: albums[index]),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Popular Songs',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              songsAsync.when(
                loading: () =>
                    const SliverToBoxAdapter(child: ShimmerSongList()),
                error: (_, __) => const SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Failed to load songs'))),
                data: (songs) => SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SongListTile(
                      song: songs[index],
                      onTap: () => ref.read(playerControllerProvider).playSong(
                            songs[index],
                            queue: songs,
                            queueIndex: index,
                          ),
                    ),
                    childCount: songs.length,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

/// Compact listener count, e.g. 1234 -> "1.2K", 2500000 -> "2.5M".
String _formatListeners(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
