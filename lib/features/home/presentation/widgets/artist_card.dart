import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/display/consumer_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_artwork.dart';
import '../../../../domain/models/artist.dart';

class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    const avatar = 84.0;
    return GestureDetector(
      onTap: () => context.push('/artist/${artist.id}'),
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Accent gradient ring.
                Container(
                  width: avatar + 6,
                  height: avatar + 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Container(
                  width: avatar + 2,
                  height: avatar + 2,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.backgroundDark,
                  ),
                ),
                AppAvatar(url: artist.imageUrl, size: avatar, label: artist.displayName),
                if (artist.isVerified)
                  Positioned(
                    right: 6,
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.backgroundDark,
                      ),
                      child: const Icon(Icons.verified_rounded,
                          color: AppColors.accent, size: 18),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              artist.displayName,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              'Artist',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
