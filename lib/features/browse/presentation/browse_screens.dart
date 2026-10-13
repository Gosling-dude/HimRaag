import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../home/presentation/widgets/album_card.dart';
import '../../home/presentation/widgets/artist_card.dart';
import '../../recommendations/recommendation_providers.dart';
import '../browse_providers.dart';
import 'song_collection_screen.dart';

class TrendingScreen extends ConsumerWidget {
  const TrendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SongCollectionScreen(
        title: 'Trending Now',
        subtitle: 'Most played',
        icon: Icons.local_fire_department_rounded,
        songs: ref.watch(allTrendingSongsProvider),
        onRetry: () => ref.invalidate(allTrendingSongsProvider),
      );
}

class NewReleasesScreen extends ConsumerWidget {
  const NewReleasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SongCollectionScreen(
        title: 'New Releases',
        subtitle: 'Recently added',
        icon: Icons.fiber_new_rounded,
        songs: ref.watch(allNewReleasesProvider),
        onRetry: () => ref.invalidate(allNewReleasesProvider),
      );
}

class RecommendedScreen extends ConsumerWidget {
  const RecommendedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personal =
        ref.watch(tasteSeedsProvider).valueOrNull?.isNotEmpty ?? false;
    return SongCollectionScreen(
      title: personal ? 'Recommended for You' : 'Popular Picks',
      subtitle: personal ? 'Based on what you listen to' : 'Popular right now',
      icon: Icons.auto_awesome_rounded,
      songs: ref.watch(recommendedSongsProvider),
      onRetry: () => ref.invalidate(tasteSeedsProvider),
      emptyMessage: 'Play a few songs to get recommendations.',
    );
  }
}

class FestivalScreen extends ConsumerWidget {
  const FestivalScreen({super.key, required this.festival});

  final String festival;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(festivalSongsProvider(festival));
    final exact = async.valueOrNull?.exact ?? true;
    return SongCollectionScreen(
      title: festival,
      subtitle: 'Festival songs',
      icon: Icons.celebration_rounded,
      songs: async.whenData((f) => f.songs),
      onRetry: () => ref.invalidate(festivalSongsProvider(festival)),
      notice: exact
          ? null
          : 'No songs are tagged for $festival yet — here are all our '
              'festival songs.',
      emptyMessage: 'No festival songs yet.',
    );
  }
}

/// Every album as a grid.
class AlbumsScreen extends ConsumerWidget {
  const AlbumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(allAlbumsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Albums')),
      body: albums.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Retry(onRetry: () => ref.invalidate(allAlbumsProvider)),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No albums yet.'))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisExtent: 210,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => Center(child: AlbumCard(album: list[i])),
              ),
      ),
    );
  }
}

/// Every artist as a grid, artists with a photo first.
class ArtistsScreen extends ConsumerWidget {
  const ArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(allArtistsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Artists')),
      body: artists.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            _Retry(onRetry: () => ref.invalidate(allArtistsProvider)),
        data: (list) => list.isEmpty
            ? const Center(child: Text('No artists yet.'))
            : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,
                  mainAxisExtent: 150,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 16,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) =>
                    Center(child: ArtistCard(artist: list[i])),
              ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textSecondaryDark),
          const SizedBox(height: 12),
          const Text('Failed to load'),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ]),
      );
}
