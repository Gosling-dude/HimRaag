import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/remote/firebase_song_request_datasource.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Songs listeners asked for from Search ("no results") or Library.
class RequestsSection extends ConsumerStatefulWidget {
  const RequestsSection({super.key});

  @override
  ConsumerState<RequestsSection> createState() => _RequestsSectionState();
}

class _RequestsSectionState extends ConsumerState<RequestsSection> {
  bool _showHandled = false;

  Future<void> _setStatus(SongRequest r, String status) async {
    try {
      await ref.read(adminSongRequestDsProvider).setStatus(r.id, status);
      ref.invalidate(songRequestsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(songRequestsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('Song Requests',
            subtitle: 'Songs listeners asked for when Search found nothing.',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              FilterChip(
                label: const Text('Show handled'),
                selected: _showHandled,
                onSelected: (v) => setState(() => _showHandled = v),
              ),
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(songRequestsProvider),
              ),
            ])),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed: $e')),
            data: (all) {
              final requests = _showHandled
                  ? all
                  : all.where((r) => r.status == SongRequest.statusNew).toList();
              if (requests.isEmpty) {
                return const Center(child: Text('No song requests.'));
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _RequestTile(
                    request: requests[i],
                    onStatus: (s) => _setStatus(requests[i], s),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.onStatus});

  final SongRequest request;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final who = [r.userName, r.userEmail].where((s) => s.isNotEmpty).join(' · ');
    final isNew = r.status == SongRequest.statusNew;
    return ListTile(
      leading: Icon(
        isNew ? Icons.library_add : Icons.check_circle_outline,
        color: isNew ? AppColors.accent : AppColors.textSecondaryDark,
      ),
      title: Text(r.artist.isEmpty ? r.songTitle : '${r.songTitle} — ${r.artist}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (r.link.isNotEmpty) SelectableText(r.link),
          if (r.details.isNotEmpty) Text(r.details),
          if (r.searchQuery.isNotEmpty && r.searchQuery != r.songTitle)
            Text('Searched: "${r.searchQuery}"'),
          Text([
            if (who.isNotEmpty) who,
            if (r.createdAt != null) '${r.createdAt}',
            if (!isNew) r.status,
          ].join(' · ')),
        ],
      ),
      isThreeLine: true,
      trailing: isNew
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              TextButton(
                onPressed: () => onStatus(SongRequest.statusAdded),
                child: const Text('Added'),
              ),
              TextButton(
                onPressed: () => onStatus(SongRequest.statusDismissed),
                child: const Text('Dismiss'),
              ),
            ])
          : TextButton(
              onPressed: () => onStatus(SongRequest.statusNew),
              child: const Text('Reopen'),
            ),
    );
  }
}
