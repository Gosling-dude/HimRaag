import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/album.dart';
import '../../../../domain/models/artist.dart';
import '../../../../domain/models/song.dart';
import '../../../home/presentation/widgets/album_card.dart';
import '../../../home/presentation/widgets/artist_card.dart';
import '../../../home/presentation/widgets/shimmer_loading.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../../../player/providers/player_providers.dart';
import '../../providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final hasQuery = query.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: _SearchBar(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
          onClear: () {
            _controller.clear();
            ref.read(searchQueryProvider.notifier).state = '';
          },
        ),
        automaticallyImplyLeading: false,
      ),
      body: hasQuery ? const _SearchResults() : const _BrowseView(),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      autofocus: false,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Search Pahadi songs, artists, albums...',
        prefixIcon: const Icon(Icons.search_rounded,
            color: AppColors.textSecondaryDark),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: onClear,
              )
            : null,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        fillColor: AppColors.cardDark,
        filled: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    final activeTab = ref.watch(activeFilterTabProvider);

    return results.when(
      loading: () => const ShimmerSongList(),
      error: (e, _) => Center(
        child: Text('Search failed. Check your connection.',
            style: Theme.of(context).textTheme.bodyMedium),
      ),
      data: (result) {
        if (result.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off_rounded,
                    size: 64, color: AppColors.textSecondaryDark),
                const SizedBox(height: 16),
                Text('No results for "${result.query}"',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords or filters',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                ),
              ],
            ),
          );
        }

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _FilterTabs(activeTab: activeTab),
            ),
            if (activeTab == 'All' || activeTab == 'Songs')
              _SongResults(songs: result.songs),
            if (activeTab == 'All' || activeTab == 'Artists')
              _ArtistResults(artists: result.artists),
            if (activeTab == 'All' || activeTab == 'Albums')
              _AlbumResults(albums: result.albums),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        );
      },
    );
  }
}

class _FilterTabs extends ConsumerWidget {
  const _FilterTabs({required this.activeTab});

  final String activeTab;

  static const _tabs = ['All', 'Songs', 'Artists', 'Albums'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isActive = tab == activeTab;
          return GestureDetector(
            onTap: () => ref.read(activeFilterTabProvider.notifier).state = tab,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.cardDark,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tab,
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.textSecondaryDark,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SongResults extends ConsumerWidget {
  const _SongResults({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (songs.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child:
                  Text('Songs', style: Theme.of(context).textTheme.titleMedium),
            );
          }
          final song = songs[index - 1];
          return SongListTile(
            song: song,
            onTap: () => ref.read(playerControllerProvider).playSong(
                  song,
                  queue: songs,
                  queueIndex: index - 1,
                ),
          );
        },
        childCount: songs.length + 1,
      ),
    );
  }
}

class _ArtistResults extends StatelessWidget {
  const _ArtistResults({required this.artists});

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                Text('Artists', style: Theme.of(context).textTheme.titleMedium),
          ),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: artists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) =>
                  ArtistCard(artist: artists[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlbumResults extends StatelessWidget {
  const _AlbumResults({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                Text('Albums', style: Theme.of(context).textTheme.titleMedium),
          ),
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: albums.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => AlbumCard(album: albums[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseView extends StatelessWidget {
  const _BrowseView();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Text('Browse by Region',
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final region = AppConstants.pahadiRegions[index];
                return GestureDetector(
                  onTap: () => context.push('/region/$region'),
                  child: _RegionCard(region: region),
                );
              },
              childCount: AppConstants.pahadiRegions.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text('Browse by Genre',
                style: Theme.of(context).textTheme.titleLarge),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.6,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final genre = AppConstants.pahadiGenres[index];
                return GestureDetector(
                  onTap: () => context.push('/category/$genre'),
                  child: _GenreCard(genre: genre),
                );
              },
              childCount: AppConstants.pahadiGenres.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 140)),
      ],
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({required this.region});

  final String region;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.regionColors[region] ?? AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.landscape_rounded, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(
            region,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class _GenreCard extends StatelessWidget {
  const _GenreCard({required this.genre});

  final String genre;

  static final _icons = {
    'Folk': Icons.music_note_rounded,
    'Devotional': Icons.self_improvement_rounded,
    'Festival': Icons.celebration_rounded,
    'Wedding': Icons.favorite_rounded,
    'Seasonal': Icons.wb_sunny_rounded,
    'Instrumental': Icons.piano_rounded,
    'Contemporary Folk': Icons.queue_music_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[genre] ?? Icons.music_note_rounded;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dividerDark),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(height: 6),
          Text(
            genre,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
