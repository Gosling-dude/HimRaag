import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_artwork.dart';
import '../../../data/remote/firebase_song_request_datasource.dart';
import '../../auth/providers/auth_providers.dart';
import '../../library/providers/library_providers.dart';
import '../../requests/song_request_sheet.dart';
import '../settings_providers.dart';

/// The signed-in listener's own requests, newest first.
final myRequestsProvider = FutureProvider<List<SongRequest>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(songRequestDatasourceProvider).mine(user.uid);
});

/// Google account page where the listener manages their password.
final _googleAccountUrl = Uri.parse('https://myaccount.google.com/security');

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final favorites = ref.watch(favoritesProvider).length;
    final downloads = ref.watch(downloadedSongsProvider).length;
    final requests = ref.watch(myRequestsProvider).valueOrNull?.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myRequestsProvider.future),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 140),
          children: [
            _Header(
              name: user?.displayLabel ?? 'Listener',
              email: user?.email,
              photoUrl: user?.photoUrl ?? '',
              memberSince: user?.createdAt,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                _Stat(
                    label: 'Favorites',
                    value: '$favorites',
                    onTap: () => context.go('/library?tab=1')),
                _Stat(
                    label: 'Downloads',
                    value: '$downloads',
                    onTap: () => context.go('/library?tab=0')),
                _Stat(
                    label: 'Requests',
                    value: requests == null ? '–' : '$requests',
                    onTap: () => context.push('/profile/requests')),
              ]),
            ),
            const _SectionLabel('Your music'),
            _Tile(
              icon: Icons.favorite_rounded,
              title: 'Favorites',
              onTap: () => context.go('/library?tab=1'),
            ),
            _Tile(
              icon: Icons.download_done_rounded,
              title: 'Downloads',
              onTap: () => context.go('/library?tab=0'),
            ),
            _Tile(
              icon: Icons.history_rounded,
              title: 'Recently played',
              onTap: () => context.go('/library?tab=2'),
            ),
            _Tile(
              icon: Icons.library_add_check_rounded,
              title: 'My song requests',
              subtitle: 'See which songs you asked us to add',
              onTap: () => context.push('/profile/requests'),
            ),
            _Tile(
              icon: Icons.library_add_rounded,
              title: 'Request a song',
              onTap: () => showSongRequestSheet(context),
            ),
            const _SectionLabel('Settings'),
            const _ThemeTile(),
            const _AutoplayTile(),
            _Tile(
              icon: Icons.delete_sweep_rounded,
              title: 'Clear listening history',
              subtitle: 'Recently played and the recommendations built on it',
              onTap: () => _clearHistory(context, ref),
            ),
            const _SectionLabel('Account'),
            _Tile(
              icon: Icons.manage_accounts_rounded,
              title: 'Manage Google account',
              subtitle:
                  'You sign in with Google — change your password and security there',
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => launchUrl(_googleAccountUrl,
                  mode: LaunchMode.externalApplication),
            ),
            _Tile(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              onTap: () => _signOut(context, ref),
            ),
            _Tile(
              icon: Icons.person_remove_rounded,
              title: 'Delete account',
              color: AppColors.error,
              onTap: () => _deleteAccount(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context,
        title: 'Clear listening history?',
        body: 'Your recently played list will be emptied. Favorites and '
            'downloads stay.',
        action: 'Clear');
    if (!ok) return;
    ref.read(recentlyPlayedProvider.notifier).clearAll();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listening history cleared')));
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context,
        title: 'Sign out?',
        body: 'Your downloads and favorites stay on this phone.',
        action: 'Sign out');
    if (!ok) return;
    // The router sends signed-out users to /sign-in.
    await ref.read(authRepositoryProvider).signOut();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(context,
        title: 'Delete your account?',
        body: 'This permanently deletes your HimRaag account and your song '
            'requests, and clears your favorites and listening history on '
            'this phone. Downloaded songs stay until you remove them. This '
            "can't be undone.",
        action: 'Delete',
        destructive: true);
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final user = ref.read(currentUserProvider);
    try {
      if (user != null) {
        await ref.read(songRequestDatasourceProvider).deleteMine(user.uid);
      }
      await ref.read(favoritesProvider.notifier).clearAll();
      ref.read(recentlyPlayedProvider.notifier).clearAll();
      await ref.read(authRepositoryProvider).deleteAccount();
      messenger.showSnackBar(
          const SnackBar(content: Text('Your account has been deleted')));
    } catch (e) {
      debugPrint('[PROFILE] delete account failed: $e');
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't delete your account. Please try again.")));
    }
  }
}

Future<bool> _confirm(BuildContext context,
    {required String title,
    required String body,
    required String action,
    bool destructive = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: AppColors.error)
              : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.photoUrl,
    this.email,
    this.memberSince,
  });

  final String name;
  final String photoUrl;
  final String? email;
  final DateTime? memberSince;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final since = memberSince;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(children: [
        AppAvatar(url: photoUrl, size: 76, label: name),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              if (email != null)
                Text(email!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textSecondaryDark),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              if (since != null)
                Text(
                    'Listening since ${_months[since.month - 1]} ${since.year}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondaryDark)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textSecondaryDark)),
          ]),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
        child: Text(text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.textSecondaryDark, letterSpacing: 1.2)),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: color ?? AppColors.primaryLight),
        title:
            Text(title, style: color == null ? null : TextStyle(color: color)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      );
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return ListTile(
      leading:
          const Icon(Icons.dark_mode_rounded, color: AppColors.primaryLight),
      title: const Text('Theme'),
      trailing: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
        ],
        selected: {mode},
        onSelectionChanged: (s) =>
            ref.read(themeModeProvider.notifier).set(s.first),
      ),
    );
  }
}

class _AutoplayTile extends ConsumerWidget {
  const _AutoplayTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      secondary: const Icon(Icons.all_inclusive_rounded,
          color: AppColors.primaryLight),
      title: const Text('Autoplay'),
      subtitle: const Text('Keep playing similar songs when your queue ends'),
      value: ref.watch(autoplayEnabledProvider),
      onChanged: (v) => ref.read(autoplayEnabledProvider.notifier).set(v),
    );
  }
}
