import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/models/song.dart';
import '../../domain/models/submission.dart';
import '../admin_auth.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Data-quality view: the same checks as `scripts/validate_catalog.js`,
/// computed client-side over the loaded catalog.
class DataQualitySection extends ConsumerWidget {
  const DataQualitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(dataQualityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Data Quality',
          subtitle: 'Catalog health. Run scripts/validate_catalog.js for live '
              'broken-link checks.',
          trailing: IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => refreshCatalog(ref),
          ),
        ),
        Expanded(
          child: reportAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed: $e')),
            data: (r) => ListView(
              children: [
                if (r.total == 0)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.verified, color: AppColors.success),
                      title: Text('No data-quality issues found.'),
                    ),
                  ),
                _issue(context, 'Rights issues (published but uncleared)',
                    r.rightsIssues, AppColors.error),
                _issue(context, 'Zero / missing duration', r.zeroDuration,
                    AppColors.error),
                _issueStrings(context, 'Duplicate songs (title + artist)',
                    r.duplicates, AppColors.warning),
                _issue(context, 'Orphan artist reference', r.orphanArtist,
                    AppColors.warning),
                _issue(context, 'Orphan album reference', r.orphanAlbum,
                    AppColors.warning),
                _issue(context, 'Missing artwork', r.missingArtwork,
                    AppColors.warning),
                _issue(context, 'Missing lyrics', r.missingLyrics,
                    AppColors.info),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _issue(
      BuildContext context, String label, List<Song> songs, Color color) {
    return Card(
      child: ExpansionTile(
        leading: Icon(
            songs.isEmpty ? Icons.check_circle_outline : Icons.warning_amber,
            color: songs.isEmpty ? AppColors.success : color),
        title: Text(label),
        trailing: Text('${songs.length}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        children: songs
            .take(50)
            .map((s) => ListTile(
                  dense: true,
                  title: Text(s.title),
                  subtitle: Text('${s.artistName} · ${s.id}'),
                ))
            .toList(),
      ),
    );
  }

  Widget _issueStrings(
      BuildContext context, String label, List<String> items, Color color) {
    return Card(
      child: ExpansionTile(
        leading: Icon(
            items.isEmpty ? Icons.check_circle_outline : Icons.warning_amber,
            color: items.isEmpty ? AppColors.success : color),
        title: Text(label),
        trailing: Text('${items.length}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        children:
            items.take(50).map((s) => ListTile(dense: true, title: Text(s))).toList(),
      ),
    );
  }
}

/// Admin review queue for artist submissions.
class SubmissionsSection extends ConsumerWidget {
  const SubmissionsSection({super.key});

  Future<void> _decide(
      WidgetRef ref, BuildContext context, Submission s, String status) async {
    try {
      await ref.read(adminSubmissionDsProvider).setStatus(s.id, status);
      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
            action: 'submission_$status',
            entityType: 'submission',
            entityId: s.id,
            actor: actor,
            detail: '${s.title} by ${s.artistName}',
          );
      ref.invalidate(pendingSubmissionsProvider);
      if (context.mounted) showSnack(context, 'Submission $status.');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingSubmissionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Submissions',
            subtitle: 'Pending artist-contributor uploads awaiting review.'),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed: $e')),
            data: (subs) {
              if (subs.isEmpty) {
                return const Center(child: Text('No pending submissions.'));
              }
              return ListView.separated(
                itemCount: subs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final s = subs[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${s.title} — ${s.artistName}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${s.region}/${s.language} · ${s.genre} · '
                              'license: ${s.license.isEmpty ? "—" : s.license}'),
                          if (s.rightsNote.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Rights note: ${s.rightsNote}',
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic)),
                          ],
                          const SizedBox(height: 12),
                          Row(children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  _decide(ref, context, s, 'approved'),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _decide(ref, context, s, 'rejected'),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                          ]),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Append-only audit trail of moderation actions.
class AuditSection extends ConsumerWidget {
  const AuditSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(auditLogProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Audit Log',
            subtitle: 'Recent moderation & import activity.',
            trailing: IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(auditLogProvider),
            )),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed: $e')),
            data: (entries) {
              if (entries.isEmpty) {
                return const Center(child: Text('No audit entries yet.'));
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.history),
                      title: Text('${e.action} · ${e.entityType} · ${e.detail}'),
                      subtitle: Text('${e.actor}'
                          '${e.createdAt != null ? " · ${e.createdAt}" : ""}'),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
