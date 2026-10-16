import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/network/artwork_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/display/consumer_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/song.dart';
import '../../../player/presentation/player_navigation.dart';
import '../../../songs/providers/song_collection_providers.dart';
import 'auto_advancing_carousel.dart';

class FeaturedBanner extends ConsumerWidget {
  const FeaturedBanner({super.key, required this.songs});

  /// The full featured list — featured songs first, then the rest of the
  /// eligible catalog. The banner shows the first [slideCount]; playback
  /// queues all of it (and keeps growing from [SongCollection.featured]), so
  /// it never stops after the last slide's song.
  final List<Song> songs;

  static const int slideCount = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slides = songs.take(slideCount).toList();

    return AutoAdvancingCarousel(
      itemCount: slides.length,
      itemBuilder: (context, index) => _BannerItem(
        song: slides[index],
        onTap: () => playSongAndOpenPlayer(
          context,
          ref,
          slides[index],
          // The slides are the head of [songs], so the index carries over.
          queue: songs,
          queueIndex: index,
          source: ref
              .read(songCollectionQueueSourceProvider(SongCollection.featured)),
        ),
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  const _BannerItem({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.cardDark,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: song.artworkUrl,
              cacheManager: ArtworkCacheManager.instance,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.surfaceDark),
              errorWidget: (_, __, ___) =>
                  Container(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      song.displayRegion,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    song.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    song.displayArtist,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerBanner extends StatelessWidget {
  const ShimmerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.shimmerBase,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
