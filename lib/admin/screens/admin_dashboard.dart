import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../admin_auth.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';
import 'catalog_section.dart';
import 'import_section.dart';
import 'insight_sections.dart';
import 'review_section.dart';

/// Full admin console: navigation rail + section content.
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key, required this.session});

  final AdminSession session;

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _index = 0;

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
    (Icons.music_note_outlined, Icons.music_note, 'Songs'),
    (Icons.album_outlined, Icons.album, 'Albums'),
    (Icons.people_outline, Icons.people, 'Artists'),
    (Icons.inbox_outlined, Icons.inbox, 'Submissions'),
    (Icons.upload_file_outlined, Icons.upload_file, 'Import'),
    (Icons.rate_review_outlined, Icons.rate_review, 'Review'),
    (Icons.health_and_safety_outlined, Icons.health_and_safety, 'Data Quality'),
    (Icons.history_outlined, Icons.history, 'Audit'),
  ];

  Widget _section() {
    switch (_index) {
      case 0:
        return const _OverviewSection();
      case 1:
        return const SongsSection();
      case 2:
        return const AlbumsSection();
      case 3:
        return const ArtistsSection();
      case 4:
        return const SubmissionsSection();
      case 5:
        return const ImportSection();
      case 6:
        return const ReviewSection();
      case 7:
        return const DataQualitySection();
      case 8:
        return const AuditSection();
      default:
        return const _OverviewSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width > 1100,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                const Icon(Icons.landscape_rounded,
                    color: AppColors.primary, size: 32),
                const SizedBox(height: 8),
                if (MediaQuery.sizeOf(context).width > 1100)
                  const Text('HimRaag',
                      style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Sign out (${widget.session.email})',
                    icon: const Icon(Icons.logout),
                    onPressed: () =>
                        ref.read(adminAuthControllerProvider).signOut(),
                  ),
                ),
              ),
            ),
            destinations: _destinations
                .map((d) => NavigationRailDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3),
                    ))
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _section(),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewSection extends ConsumerWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songs = ref.watch(adminSongsProvider);
    final albums = ref.watch(adminAlbumsProvider);
    final artists = ref.watch(adminArtistsProvider);
    final subs = ref.watch(pendingSubmissionsProvider);
    final quality = ref.watch(dataQualityProvider);
    final review = ref.watch(metadataReviewProvider);

    String count(AsyncValue<List> a) =>
        a.maybeWhen(data: (d) => d.length.toString(), orElse: () => '—');

    final pending = songs.maybeWhen(
        data: (d) =>
            d.where((s) => s.approvalStatus.wire == 'pending').length.toString(),
        orElse: () => '—');
    final demo = songs.maybeWhen(
        data: (d) => d.where((s) => s.isDemo).length.toString(),
        orElse: () => '—');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Content Overview',
            subtitle: 'HimRaag catalog at a glance.',
            trailing: IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => refreshCatalog(ref),
            )),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    MetricCard(label: 'Songs', value: count(songs), icon: Icons.music_note),
                    MetricCard(label: 'Albums', value: count(albums), icon: Icons.album, color: AppColors.accent),
                    MetricCard(label: 'Artists', value: count(artists), icon: Icons.people, color: AppColors.info),
                    MetricCard(label: 'Pending approval', value: pending, icon: Icons.pending_actions, color: AppColors.warning),
                    MetricCard(label: 'Demo tracks', value: demo, icon: Icons.science_outlined, color: AppColors.info),
                    MetricCard(label: 'Submissions', value: count(subs), icon: Icons.inbox, color: AppColors.primaryLight),
                    MetricCard(
                      label: 'Needs metadata review',
                      value: review.maybeWhen(
                          data: (r) => r.needsReview.length.toString(),
                          orElse: () => '—'),
                      icon: Icons.rate_review,
                      color: review.maybeWhen(
                          data: (r) => r.isEmpty
                              ? AppColors.success
                              : AppColors.warning,
                          orElse: () => AppColors.primary),
                    ),
                    MetricCard(
                      label: 'Data-quality issues',
                      value: quality.maybeWhen(
                          data: (r) => r.total.toString(), orElse: () => '—'),
                      icon: Icons.health_and_safety,
                      color: quality.maybeWhen(
                          data: (r) => r.total == 0 ? AppColors.success : AppColors.error,
                          orElse: () => AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  color: AppColors.info.withValues(alpha: 0.08),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(children: [
                      Icon(Icons.info_outline, color: AppColors.info),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Demo content is license=DEMO_ONLY and never published. '
                          'Replace it with licensed catalog content via Import or '
                          'the Node pipeline before public release. See '
                          'docs/CONTENT_SYSTEM.md.',
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
