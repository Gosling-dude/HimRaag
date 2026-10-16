import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/artwork_cache.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/legal_links.dart';
import '../../../../data/local/hive_boxes.dart';
import '../../../../data/services/download_service.dart';
import '../../../../domain/models/app_user.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../auth/providers/user_profile_providers.dart';
import '../../../library/providers/library_providers.dart';

/// Total bytes on disk used by downloaded audio.
final _downloadStorageProvider = FutureProvider<int>((ref) {
  return ref.watch(downloadServiceProvider).getTotalDownloadedSizeBytes();
});

/// Account & personalization hub — reachable from the Home avatar.
/// Read-mostly: it surfaces existing auth/profile/library state and links to
/// the existing Preferences screen for edits. Passwords are never shown
/// (Google/guest sign-in — the app never even holds one).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider);
    final favoritesCount = ref.watch(favoritesProvider).length;
    final downloads = ref.watch(downloadedSongsProvider);
    final storageAsync = ref.watch(_downloadStorageProvider);
    final recentlyPlayedCount = HiveBoxes.recentlyPlayed.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const _SignedOutView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                _ProfileHeader(user: user),
                const SizedBox(height: 24),
                _StatsGrid(
                  favoritesCount: favoritesCount,
                  playlistCount: 0,
                  recentlyPlayedCount: recentlyPlayedCount,
                  downloadCount: downloads.length,
                ),
                const SizedBox(height: 12),
                _StorageRow(storageAsync: storageAsync),
                const SizedBox(height: 24),
                const _SectionTitle('Your Preferences'),
                const SizedBox(height: 10),
                _PreferencesCard(
                  regions: profile.preferredRegions,
                  languages: profile.preferredLanguages,
                  genres: profile.preferredGenres,
                ),
                const SizedBox(height: 24),
                const _SectionTitle('Account'),
                const SizedBox(height: 10),
                _AccountCard(user: user),
                const SizedBox(height: 24),
                const _SectionTitle('Privacy & Legal'),
                const SizedBox(height: 10),
                const LegalLinksCard(),
                const SizedBox(height: 28),
                _SignOutButton(user: user),
              ],
            ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_circle_rounded,
                size: 80, color: AppColors.textSecondaryDark),
            const SizedBox(height: 16),
            Text('You are not signed in',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Sign in to sync your favorites, preferences\nand listening history across devices.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondaryDark,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/sign-in'),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrl = user.photoUrl;
    final createdAt = user.createdAt;

    return Column(
      children: [
        CircleAvatar(
          radius: 46,
          backgroundColor: AppColors.primary.withValues(alpha: 0.25),
          foregroundImage: (photoUrl != null && photoUrl.isNotEmpty)
              ? CachedNetworkImageProvider(photoUrl,
                  cacheManager: ArtworkCacheManager.instance)
              : null,
          child: Text(
            user.displayLabel.isNotEmpty
                ? user.displayLabel[0].toUpperCase()
                : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.displayLabel,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Change display name',
              icon: const Icon(Icons.edit_rounded,
                  size: 18, color: AppColors.textSecondaryDark),
              onPressed: () => _changeDisplayName(context, ref, user),
            ),
          ],
        ),
        if (user.email != null && user.email!.isNotEmpty)
          Text(
            user.email!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryDark,
                ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _Badge(
              icon: user.isGuest
                  ? Icons.person_outline_rounded
                  : Icons.verified_user_rounded,
              label: user.isGuest ? 'Guest account' : 'Google account',
            ),
            if (createdAt != null)
              _Badge(
                icon: Icons.cake_rounded,
                label: 'Member since ${_formatDate(createdAt)}',
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _changeDisplayName(
      BuildContext context, WidgetRef ref, AppUser user) async {
    final controller = TextEditingController(text: user.displayName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Display name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == user.displayName) {
      return;
    }
    try {
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      await fbUser?.updateDisplayName(newName);
      await fbUser?.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update name — try again')),
        );
      }
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.accent),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.favoritesCount,
    required this.playlistCount,
    required this.recentlyPlayedCount,
    required this.downloadCount,
  });

  final int favoritesCount;
  final int playlistCount;
  final int recentlyPlayedCount;
  final int downloadCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.favorite_rounded, '$favoritesCount', 'Favorites'),
      (Icons.queue_music_rounded, '$playlistCount', 'Playlists'),
      (Icons.history_rounded, '$recentlyPlayedCount', 'Recently Played'),
      (Icons.download_done_rounded, '$downloadCount', 'Downloads'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.4,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        for (final (icon, value, label) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.cardDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondaryDark)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.storageAsync});

  final AsyncValue<int> storageAsync;

  @override
  Widget build(BuildContext context) {
    final label = storageAsync.when(
      data: (bytes) {
        final mb = bytes / (1024 * 1024);
        return mb >= 1024
            ? '${(mb / 1024).toStringAsFixed(2)} GB used by downloads'
            : '${mb.toStringAsFixed(1)} MB used by downloads';
      },
      loading: () => 'Calculating storage…',
      error: (_, __) => 'Storage unavailable',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.regions,
    required this.languages,
    required this.genres,
  });

  final List<String> regions;
  final List<String> languages;
  final List<String> genres;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PrefRow(
            icon: Icons.landscape_rounded,
            label: 'Regions',
            values: regions,
          ),
          const SizedBox(height: 12),
          _PrefRow(
            icon: Icons.translate_rounded,
            label: 'Languages',
            values: languages,
          ),
          const SizedBox(height: 12),
          _PrefRow(
            icon: Icons.music_note_rounded,
            label: 'Genres',
            values: genres,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/preferences?from=settings'),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Edit Preferences'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefRow extends StatelessWidget {
  const _PrefRow({
    required this.icon,
    required this.label,
    required this.values,
  });

  final IconData icon;
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondaryDark)),
        ),
        Expanded(
          child: values.isEmpty
              ? const Text('Not set',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondaryDark))
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final v in values)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(v,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.badge_rounded,
            title: 'Sign-in method',
            value: user.isGuest ? 'Guest' : 'Google',
          ),
          const Divider(height: 1, indent: 52),
          _InfoTile(
            icon: Icons.calendar_month_rounded,
            title: 'Account created',
            value: user.createdAt != null
                ? _formatDate(user.createdAt!)
                : 'Unknown',
          ),
          const Divider(height: 1, indent: 52),
          _InfoTile(
            icon: Icons.fingerprint_rounded,
            title: 'User ID',
            value: user.uid.length > 14
                ? '${user.uid.substring(0, 14)}…'
                : user.uid,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: AppColors.accent),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: const TextStyle(
            fontSize: 13, color: AppColors.textSecondaryDark),
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sign out?'),
              content: Text(
                user.isGuest
                    ? 'Your downloads and favorites stay on this device.'
                    : 'You can sign back in anytime. Downloads and favorites stay on this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await ref.read(authRepositoryProvider).signOut();
          if (context.mounted) context.go('/sign-in');
        },
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Sign Out'),
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
