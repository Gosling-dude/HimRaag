import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/song.dart';
import '../../../player/providers/player_providers.dart';

class SongListTile extends ConsumerWidget {
  const SongListTile({
    super.key,
    required this.song,
    required this.onTap,
    this.trailing,
    this.showIndex,
    this.index,
  });

  final Song song;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool? showIndex;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentSong = ref.watch(currentSongProvider);
    final isCurrentlyPlaying = currentSong?.id == song.id;
    final isPlaying = ref.watch(isPlayingProvider);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: song.artworkUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 52,
                height: 52,
                color: AppColors.primary.withValues(alpha: 0.3),
                child: const Icon(Icons.music_note,
                    color: AppColors.primary, size: 26),
              ),
            ),
          ),
          if (isCurrentlyPlaying)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Icon(
                    isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        song.title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: isCurrentlyPlaying ? AppColors.primary : null,
              fontWeight: isCurrentlyPlaying ? FontWeight.w600 : null,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          Text(
            song.artistName,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (song.region.isNotEmpty) ...[
            Text(
              ' • ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              song.region,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.regionColors[song.region],
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      trailing: trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (song.isDownloaded)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.offline_pin_rounded,
                      color: AppColors.downloadComplete, size: 16),
                ),
              Text(
                song.durationFormatted,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
    );
  }
}
