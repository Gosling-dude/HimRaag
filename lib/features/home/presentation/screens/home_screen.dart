import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/album.dart';
import '../../../../domain/models/artist.dart';
import '../../../../domain/models/song.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../player/providers/player_providers.dart';
import '../../providers/home_providers.dart';
import '../widgets/album_card.dart';
import '../widgets/artist_card.dart';
import '../widgets/featured_banner.dart';
import '../widgets/region_chip.dart';
import '../widgets/section_header.dart';
import '../widgets/song_card.dart';
import '../widgets/shimmer_loading.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(featuredSongsProvider);
          ref.invalidate(trendingSongsProvider);
          ref.invalidate(newReleasesProvider);
          ref.invalidate(featuredAlbumsProvider);
          ref.invalidate(featuredArtistsProvider);
        },
        child: CustomScrollView(
          slivers: [
            _HomeAppBar(userName: user?.displayLabel),
            const _FeaturedSection(),
            const _RegionPicker(),
            const _TrendingSection(),
            const _NewReleasesSection(),
            const _AlbumsSection(),
            const _ArtistsSection(),
            const _FestivalSection(),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({this.userName});

  final String? userName;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return SliverAppBar(
      floating: true,
      pinned: false,
      expandedHeight: 80,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        greeting,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                      ),
                      Text(
                        userName ?? 'Welcome to HimRaag',
                        style: Theme.of(context).textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturedSection extends ConsumerWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final featured = ref.watch(featuredSongsProvider);

    return SliverToBoxAdapter(
      child: featured.when(
        data: (songs) {
          if (songs.isEmpty) return const SizedBox.shrink();
          return FeaturedBanner(songs: songs);
        },
        loading: () => const ShimmerBanner(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _RegionPicker extends ConsumerStatefulWidget {
  const _RegionPicker();

  @override
  ConsumerState<_RegionPicker> createState() => _RegionPickerState();
}

class _RegionPickerState extends ConsumerState<_RegionPicker> {
  String _selected = 'All';

  final _regions = ['All', ...AppConstants.pahadiRegions];

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Text('By Region',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _regions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final region = _regions[index];
                return RegionChip(
                  label: region,
                  isSelected: _selected == region,
                  onTap: () => setState(() => _selected = region),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingSection extends ConsumerWidget {
  const _TrendingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(trendingSongsProvider);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: SectionHeader(
              title: 'Trending Now',
              onSeeAll: () => context.push('/search'),
            ),
          ),
          trending.when(
            data: (songs) => _HorizontalSongList(songs: songs),
            loading: () => const ShimmerHorizontalList(),
            error: (e, _) => _ErrorWidget(message: e.toString()),
          ),
        ],
      ),
    );
  }
}

class _NewReleasesSection extends ConsumerWidget {
  const _NewReleasesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newReleases = ref.watch(newReleasesProvider);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: SectionHeader(
              title: 'New Releases',
              onSeeAll: () => context.push('/search'),
            ),
          ),
          newReleases.when(
            data: (songs) => _HorizontalSongList(songs: songs),
            loading: () => const ShimmerHorizontalList(),
            error: (e, _) => _ErrorWidget(message: e.toString()),
          ),
        ],
      ),
    );
  }
}

class _AlbumsSection extends ConsumerWidget {
  const _AlbumsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(featuredAlbumsProvider);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: SectionHeader(
              title: 'Popular Albums',
              onSeeAll: () {},
            ),
          ),
          albums.when(
            data: (albumList) => _HorizontalAlbumList(albums: albumList),
            loading: () => const ShimmerHorizontalList(),
            error: (e, _) => _ErrorWidget(message: e.toString()),
          ),
        ],
      ),
    );
  }
}

class _ArtistsSection extends ConsumerWidget {
  const _ArtistsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(featuredArtistsProvider);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: SectionHeader(
              title: 'Featured Artists',
              onSeeAll: () {},
            ),
          ),
          artists.when(
            data: (artistList) => _HorizontalArtistList(artists: artistList),
            loading: () => const ShimmerHorizontalList(),
            error: (e, _) => _ErrorWidget(message: e.toString()),
          ),
        ],
      ),
    );
  }
}

class _FestivalSection extends StatelessWidget {
  const _FestivalSection();

  @override
  Widget build(BuildContext context) {
    final festivals = AppConstants.festivals.take(6).toList();

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child:
                SectionHeader(title: 'Festival Collections', onSeeAll: () {}),
          ),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: festivals.length,
            itemBuilder: (context, index) {
              return _FestivalCard(name: festivals[index]);
            },
          ),
        ],
      ),
    );
  }
}

class _FestivalCard extends StatelessWidget {
  const _FestivalCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = [
      [const Color(0xFF2E7D32), const Color(0xFF66BB6A)],
      [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)],
      [const Color(0xFFC62828), const Color(0xFFEF5350)],
      [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
      [const Color(0xFF4E342E), const Color(0xFF8D6E63)],
      [const Color(0xFF00695C), const Color(0xFF26A69A)],
    ];
    final gradient = colors[name.hashCode % colors.length];

    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.celebration_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HorizontalSongList extends ConsumerWidget {
  const _HorizontalSongList({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: songs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SongCard(
            song: songs[index],
            onTap: () => ref.read(playerControllerProvider).playSong(
                  songs[index],
                  queue: songs,
                  queueIndex: index,
                ),
          );
        },
      ),
    );
  }
}

class _HorizontalAlbumList extends StatelessWidget {
  const _HorizontalAlbumList({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: albums.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) => AlbumCard(album: albums[index]),
      ),
    );
  }
}

class _HorizontalArtistList extends StatelessWidget {
  const _HorizontalArtistList({required this.artists});

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: artists.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) => ArtistCard(artist: artists[index]),
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  const _ErrorWidget({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        'Failed to load content',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryDark,
            ),
      ),
    );
  }
}
