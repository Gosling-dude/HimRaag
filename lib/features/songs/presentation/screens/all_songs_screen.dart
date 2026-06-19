import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../data/services/audio_player_service.dart';
import '../../../../domain/models/song.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../../../player/providers/player_providers.dart';
import '../../providers/all_songs_providers.dart';

/// "All Songs" — every approved song in one place, with search, region/artist
/// filters, infinite-scroll pagination, and queue playback (Play All / Shuffle
/// All / Repeat All). Reachable from Home, Library and Search.
class AllSongsScreen extends ConsumerStatefulWidget {
  const AllSongsScreen({super.key});

  @override
  ConsumerState<AllSongsScreen> createState() => _AllSongsScreenState();
}

class _AllSongsScreenState extends ConsumerState<AllSongsScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(allSongsControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _playAll(List<Song> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) return;
    final controller = ref.read(playerControllerProvider);
    if (shuffle) {
      final queue = [...songs]..shuffle(Random());
      ref.read(isShuffleProvider.notifier).state = true;
      await controller.playSong(queue.first, queue: queue, queueIndex: 0);
    } else {
      await controller.playSong(songs.first, queue: songs, queueIndex: 0);
    }
  }

  Future<void> _toggleRepeatAll() async {
    final current = ref.read(repeatModeProvider);
    final next = current == RepeatMode.all ? RepeatMode.off : RepeatMode.all;
    ref.read(repeatModeProvider.notifier).state = next;
    await ref.read(audioPlayerServiceProvider).setRepeatMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allSongsControllerProvider);
    final filtered = ref.watch(filteredAllSongsProvider);
    final region = ref.watch(allSongsRegionProvider);
    final regionOptions = ref.watch(allSongsRegionOptionsProvider);
    final repeatMode = ref.watch(repeatModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Songs'),
      ),
      body: Column(
        children: [
          // Search.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(allSongsQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search all songs…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(allSongsQueryProvider.notifier).state = '';
                        },
                      ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Region filter chips.
          if (regionOptions.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: regionOptions.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final label = index == 0 ? 'All' : regionOptions[index - 1];
                  final selected = region == label;
                  return ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => ref
                        .read(allSongsRegionProvider.notifier)
                        .state = label,
                  );
                },
              ),
            ),
          // Action bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        filtered.isEmpty ? null : () => _playAll(filtered),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play All'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: filtered.isEmpty
                        ? null
                        : () => _playAll(filtered, shuffle: true),
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Shuffle'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: repeatMode == RepeatMode.all
                      ? 'Repeat All: on'
                      : 'Repeat All: off',
                  onPressed: _toggleRepeatAll,
                  icon: Icon(
                    Icons.repeat_rounded,
                    color: repeatMode == RepeatMode.all
                        ? AppColors.primary
                        : AppColors.textSecondaryDark,
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
                '${filtered.length} song${filtered.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
              ),
            ),
          ),
          // List.
          Expanded(
            child: _buildList(state, filtered),
          ),
        ],
      ),
    );
  }

  Widget _buildList(AllSongsState state, List<Song> filtered) {
    if (filtered.isEmpty) {
      if (state.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_off_rounded,
                size: 56, color: AppColors.textSecondaryDark),
            const SizedBox(height: 12),
            Text('No songs match your filters',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(allSongsControllerProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: filtered.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filtered.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return SongListTile(
            song: filtered[index],
            showIndex: true,
            index: index + 1,
            onTap: () => ref.read(playerControllerProvider).playSong(
                  filtered[index],
                  queue: filtered,
                  queueIndex: index,
                ),
          );
        },
      ),
    );
  }
}
