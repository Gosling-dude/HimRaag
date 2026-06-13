import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/download_service.dart';
import '../../../../domain/models/song.dart';
import '../../../player/providers/player_providers.dart';
import '../../providers/library_providers.dart';
import '../widgets/song_list_tile.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryDark,
          tabs: const [
            Tab(text: 'Downloads'),
            Tab(text: 'Favorites'),
            Tab(text: 'Recent'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DownloadsTab(),
          _FavoritesTab(),
          _RecentTab(),
        ],
      ),
    );
  }
}

class _DownloadsTab extends ConsumerWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadedSongsProvider);

    if (downloads.isEmpty) {
      return const _EmptyState(
        icon: Icons.download_outlined,
        title: 'No Downloads',
        subtitle:
            'Songs you download will appear here.\nListen offline anytime.',
      );
    }

    return Column(
      children: [
        _StorageInfo(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final song = downloads[index];
              return SongListTile(
                song: song,
                onTap: () => ref.read(playerControllerProvider).playSong(
                      song,
                      queue: downloads,
                      queueIndex: index,
                    ),
                trailing: _DeleteDownloadButton(song: song),
              );
            },
          ),
        ),
      ],
    );
  }
}

final _downloadedSizeBytesProvider = FutureProvider<int>((ref) {
  return ref.watch(downloadServiceProvider).getTotalDownloadedSizeBytes();
});

class _StorageInfo extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeAsync = ref.watch(_downloadedSizeBytesProvider);
    return sizeAsync.maybeWhen(
      data: (bytes) {
        final mb = bytes / (1024 * 1024);
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.cardDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.storage_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Text(
                '${mb.toStringAsFixed(1)} MB used for downloads',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _DeleteDownloadButton extends ConsumerWidget {
  const _DeleteDownloadButton({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.delete_outline_rounded),
      color: AppColors.error,
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Download'),
            content: Text('Remove "${song.title}" from downloads?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(downloadServiceProvider).deleteDownload(song.id);
          ref.read(libraryProvider.notifier).refreshDownloads();
        }
      },
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    if (favorites.isEmpty) {
      return const _EmptyState(
        icon: Icons.favorite_border_rounded,
        title: 'No Favorites',
        subtitle:
            'Songs you like will appear here.\nTap the heart icon to save.',
      );
    }

    return Center(
      child: Text('${favorites.length} favorites saved'),
    );
  }
}

class _RecentTab extends ConsumerWidget {
  const _RecentTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(recentlyPlayedProvider);

    if (recent.isEmpty) {
      return const _EmptyState(
        icon: Icons.history_rounded,
        title: 'No History',
        subtitle: 'Songs you listen to will appear here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: recent.length,
      itemBuilder: (context, index) {
        final song = recent[index];
        return SongListTile(
          song: song,
          onTap: () => ref.read(playerControllerProvider).playSong(song),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textSecondaryDark),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
