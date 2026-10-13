import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/remote/firebase_song_request_datasource.dart';
import '../../requests/song_request_sheet.dart';
import 'profile_screen.dart';

/// The listener's own song requests and what happened to each.
class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My song requests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showSongRequestSheet(context);
          ref.invalidate(myRequestsProvider);
        },
        icon: const Icon(Icons.library_add_rounded),
        label: const Text('Request a song'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myRequestsProvider.future),
        child: requests.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(children: const [
            SizedBox(height: 160),
            Center(child: Text("Couldn't load your requests. Pull to retry.")),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 140),
                  const Icon(Icons.library_add_rounded,
                      size: 56, color: AppColors.textSecondaryDark),
                  const SizedBox(height: 12),
                  Center(
                    child: Text("You haven't requested any songs yet.",
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 120),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _RequestTile(request: list[i]),
                ),
        ),
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request});

  final SongRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final (label, color) = switch (r.status) {
      SongRequest.statusAdded => ('Added', AppColors.success),
      SongRequest.statusDismissed => ('Not added', AppColors.textSecondaryDark),
      _ => ('Pending', AppColors.accent),
    };
    final when = r.createdAt;
    return ListTile(
      title:
          Text(r.artist.isEmpty ? r.songTitle : '${r.songTitle} — ${r.artist}'),
      subtitle: Text(
          [
            if (when != null) '${when.day}/${when.month}/${when.year}',
            if (r.link.isNotEmpty) r.link,
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
