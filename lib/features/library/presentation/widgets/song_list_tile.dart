import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/display/consumer_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_artwork.dart';
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
          AppArtwork(
            url: song.artworkUrl,
            size: 52,
            radius: 8,
            label: song.title,
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
            song.displayArtist,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (song.displayRegion.isNotEmpty) ...[
            Text(
              ' • ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              song.displayRegion,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.regionColors[song.displayRegion],
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
