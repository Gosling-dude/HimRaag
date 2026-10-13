import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../library/presentation/widgets/song_list_tile.dart';
import '../player/providers/player_providers.dart';
import 'recommendation_providers.dart';

/// Songs similar to [songId]; tapping one plays it with the rest queued.
Future<void> showMoreLikeThisSheet(BuildContext context, String songId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) =>
          _MoreLikeThis(songId: songId, controller: controller),
    ),
  );
}

class _MoreLikeThis extends ConsumerWidget {
  const _MoreLikeThis({required this.songId, required this.controller});

  final String songId;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similar = ref.watch(similarSongsProvider(songId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.accent),
            const SizedBox(width: 10),
            Text('More like this',
                style: Theme.of(context).textTheme.titleLarge),
          ]),
        ),
        Expanded(
          child: similar.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text("Couldn't load similar songs.")),
            data: (songs) => songs.isEmpty
                ? const Center(child: Text('No similar songs yet.'))
                : ListView.builder(
                    controller: controller,
                    itemCount: songs.length,
                    itemBuilder: (context, i) => SongListTile(
                      song: songs[i],
                      onTap: () {
                        Navigator.of(context).pop();
                        ref
                            .read(playerControllerProvider)
                            .playSong(songs[i], queue: songs, queueIndex: i);
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
