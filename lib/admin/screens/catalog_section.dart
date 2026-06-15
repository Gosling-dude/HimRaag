import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/content_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import '../admin_auth.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';
import 'song_editor.dart';

/// Songs management: search + filter (region / language / status) over the full
/// catalog, with inline approve / reject / edit / delete.
class SongsSection extends ConsumerStatefulWidget {
  const SongsSection({super.key});

  @override
  ConsumerState<SongsSection> createState() => _SongsSectionState();
}

class _SongsSectionState extends ConsumerState<SongsSection> {
  String _query = '';
  String _region = 'All';
  String _language = 'All';
  String _status = 'All';

  bool _matches(Song s) {
    if (_region != 'All' && s.region != _region) return false;
    if (_language != 'All' && s.language != _language) return false;
    if (_status != 'All' && s.approvalStatus.wire != _status) return false;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      if (!s.title.toLowerCase().contains(q) &&
          !s.artistName.toLowerCase().contains(q) &&
          !s.albumTitle.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _setStatus(Song s, ApprovalStatus status) async {
    try {
      await ref.read(adminSongDsProvider).setApprovalStatus(s.id, status);
      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
            action: status.wire,
            entityType: 'song',
            entityId: s.id,
            actor: actor,
            detail: s.title,
          );
      refreshCatalog(ref);
      if (mounted) showSnack(context, '"${s.title}" → ${status.wire}');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _delete(Song s) async {
    final ok = await confirm(context,
        title: 'Delete song?',
        message: 'Permanently delete "${s.title}"? This cannot be undone.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(adminSongDsProvider).deleteSong(s.id);
      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
          action: 'delete', entityType: 'song', entityId: s.id, actor: actor, detail: s.title);
      refreshCatalog(ref);
      if (mounted) showSnack(context, 'Deleted "${s.title}".');
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(adminSongsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Songs',
          subtitle: 'Full catalog (all statuses). Approve to publish.',
          trailing: FilledButton.icon(
            onPressed: () async {
              final saved = await SongEditorDialog.show(context);
              if (saved == true) refreshCatalog(ref);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Song'),
          ),
        ),
        _filterBar(),
        const SizedBox(height: 12),
        Expanded(
          child: songsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _error(e),
            data: (songs) {
              final filtered = songs.where(_matches).toList();
              if (filtered.isEmpty) {
                return const Center(child: Text('No songs match the filters.'));
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _row(filtered[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _row(Song s) {
    final regionColor = AppColors.regionColors[s.region] ?? AppColors.primary;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: regionColor.withValues(alpha: 0.2),
        child: Text(s.region.isNotEmpty ? s.region[0] : '?',
            style: TextStyle(color: regionColor, fontWeight: FontWeight.bold)),
      ),
      title: Row(children: [
        Flexible(child: Text(s.title, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        StatusChip(s.approvalStatus),
        const SizedBox(width: 6),
        LicenseChip(s.license),
      ]),
      subtitle: Text(
          '${s.artistName} · ${s.albumTitle.isEmpty ? "—" : s.albumTitle} · '
          '${s.region}/${s.language} · ${s.durationFormatted}',
          overflow: TextOverflow.ellipsis),
      trailing: Wrap(
        spacing: 0,
        children: [
          if (s.approvalStatus != ApprovalStatus.approved)
            IconButton(
              tooltip: 'Approve',
              icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
              onPressed: () => _setStatus(s, ApprovalStatus.approved),
            ),
          if (s.approvalStatus != ApprovalStatus.rejected)
            IconButton(
              tooltip: 'Reject',
              icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
              onPressed: () => _setStatus(s, ApprovalStatus.rejected),
            ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final saved = await SongEditorDialog.show(context, existing: s);
              if (saved == true) refreshCatalog(ref);
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(s),
          ),
        ],
      ),
    );
  }

  Widget _filterBar() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search title / artist / album',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        _filterDropdown('Region', _region, ['All', ...AppConstants.pahadiRegions],
            (v) => setState(() => _region = v)),
        _filterDropdown('Language', _language, ['All', ...ContentConstants.languages],
            (v) => setState(() => _language = v)),
        _filterDropdown('Status', _status,
            ['All', ...ApprovalStatus.values.map((s) => s.wire)],
            (v) => setState(() => _status = v)),
      ],
    );
  }

  Widget _error(Object e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Failed to load: $e',
              style: const TextStyle(color: AppColors.error)),
        ),
      );
}

Widget _filterDropdown(
    String label, String value, List<String> items, ValueChanged<String> onChanged) {
  return SizedBox(
    width: 180,
    child: DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: (v) => onChanged(v ?? value),
    ),
  );
}

/// Albums management: search + approve / reject / delete.
class AlbumsSection extends ConsumerStatefulWidget {
  const AlbumsSection({super.key});

  @override
  ConsumerState<AlbumsSection> createState() => _AlbumsSectionState();
}

class _AlbumsSectionState extends ConsumerState<AlbumsSection> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final albumsAsync = ref.watch(adminAlbumsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Albums', subtitle: 'Album catalog across all artists.'),
        SizedBox(
          width: 280,
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Search albums', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: albumsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed: $e')),
            data: (albums) {
              final list = albums
                  .where((a) =>
                      _query.isEmpty ||
                      a.title.toLowerCase().contains(_query.toLowerCase()) ||
                      a.artistName.toLowerCase().contains(_query.toLowerCase()))
                  .toList();
              if (list.isEmpty) return const Center(child: Text('No albums.'));
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _albumRow(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _albumRow(Album a) {
    return ListTile(
      leading: const Icon(Icons.album_outlined),
      title: Row(children: [
        Flexible(child: Text(a.title, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        StatusChip(a.approvalStatus),
        const SizedBox(width: 6),
        LicenseChip(a.license),
      ]),
      subtitle: Text(
          '${a.artistName} · ${a.region} · ${a.songCount} tracks · ${a.releaseYear}'),
      trailing: Wrap(children: [
        if (a.approvalStatus != ApprovalStatus.approved)
          IconButton(
            tooltip: 'Approve',
            icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
            onPressed: () => _setStatus(a, ApprovalStatus.approved),
          ),
        if (a.approvalStatus != ApprovalStatus.rejected)
          IconButton(
            tooltip: 'Reject',
            icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
            onPressed: () => _setStatus(a, ApprovalStatus.rejected),
          ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(a),
        ),
      ]),
    );
  }

  Future<void> _setStatus(Album a, ApprovalStatus status) async {
    try {
      await ref.read(adminAlbumDsProvider).setApprovalStatus(a.id, status);
      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
          action: status.wire, entityType: 'album', entityId: a.id, actor: actor, detail: a.title);
      refreshCatalog(ref);
      if (mounted) showSnack(context, '"${a.title}" → ${status.wire}');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _delete(Album a) async {
    final ok = await confirm(context,
        title: 'Delete album?',
        message: 'Delete "${a.title}"? Songs are not deleted.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(adminAlbumDsProvider).deleteAlbum(a.id);
      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
          action: 'delete', entityType: 'album', entityId: a.id, actor: actor, detail: a.title);
      refreshCatalog(ref);
      if (mounted) showSnack(context, 'Deleted "${a.title}".');
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }
}

/// Artists management: search + approve / reject / delete + verify toggle.
class ArtistsSection extends ConsumerStatefulWidget {
  const ArtistsSection({super.key});

  @override
  ConsumerState<ArtistsSection> createState() => _ArtistsSectionState();
}

class _ArtistsSectionState extends ConsumerState<ArtistsSection> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final artistsAsync = ref.watch(adminArtistsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Artists', subtitle: 'Artist profiles and verification.'),
        SizedBox(
          width: 280,
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Search artists', prefixIcon: Icon(Icons.search), isDense: true),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: artistsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed: $e')),
            data: (artists) {
              final list = artists
                  .where((a) =>
                      _query.isEmpty ||
                      a.name.toLowerCase().contains(_query.toLowerCase()))
                  .toList();
              if (list.isEmpty) return const Center(child: Text('No artists.'));
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => _artistRow(list[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _artistRow(Artist a) {
    return ListTile(
      leading: CircleAvatar(child: Text(a.name.isNotEmpty ? a.name[0] : '?')),
      title: Row(children: [
        Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        StatusChip(a.approvalStatus),
        if (a.isVerified) ...[
          const SizedBox(width: 6),
          const Icon(Icons.verified, size: 16, color: AppColors.info),
        ],
      ]),
      subtitle: Text('${a.region} · ${a.songCount} songs · ${a.albumCount} albums'),
      trailing: Wrap(children: [
        if (a.approvalStatus != ApprovalStatus.approved)
          IconButton(
            tooltip: 'Approve',
            icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
            onPressed: () => _setStatus(a, ApprovalStatus.approved),
          ),
        IconButton(
          tooltip: a.isVerified ? 'Unverify' : 'Verify',
          icon: Icon(a.isVerified ? Icons.verified : Icons.verified_outlined),
          onPressed: () => _toggleVerify(a),
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(a),
        ),
      ]),
    );
  }

  Future<void> _setStatus(Artist a, ApprovalStatus status) async {
    try {
      await ref.read(adminArtistDsProvider).setApprovalStatus(a.id, status);
      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
          action: status.wire, entityType: 'artist', entityId: a.id, actor: actor, detail: a.name);
      refreshCatalog(ref);
      if (mounted) showSnack(context, '"${a.name}" → ${status.wire}');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _toggleVerify(Artist a) async {
    try {
      await ref
          .read(adminArtistDsProvider)
          .upsertArtist(a.copyWith(isVerified: !a.isVerified));
      refreshCatalog(ref);
      if (mounted) {
        showSnack(context, '"${a.name}" ${a.isVerified ? "unverified" : "verified"}.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _delete(Artist a) async {
    final ok = await confirm(context,
        title: 'Delete artist?',
        message: 'Delete "${a.name}"? Songs/albums are not deleted.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await ref.read(adminArtistDsProvider).deleteArtist(a.id);
      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
          action: 'delete', entityType: 'artist', entityId: a.id, actor: actor, detail: a.name);
      refreshCatalog(ref);
      if (mounted) showSnack(context, 'Deleted "${a.name}".');
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }
}
