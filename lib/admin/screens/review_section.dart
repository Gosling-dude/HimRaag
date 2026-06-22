import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/content_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/validation/metadata_validator.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import '../admin_auth.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Metadata-review workflow.
///
/// Surfaces every track flagged for cleanup (locally-imported audio that came
/// in with no embedded tags, plus any catalog gap), grouped by what's missing,
/// and provides bulk-edit tools to assign artist / album / language / region /
/// genre to many tracks at once. Writes go through the same datasources as the
/// rest of the dashboard (no manual Firestore editing).
class ReviewSection extends ConsumerStatefulWidget {
  const ReviewSection({super.key});

  @override
  ConsumerState<ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends ConsumerState<ReviewSection> {
  final Set<String> _selected = {};
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(metadataReviewProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Metadata Review',
          subtitle: 'Imported tracks awaiting metadata. Select rows and use '
              'Bulk Edit to assign artist, album, language, region or genre.',
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
            data: (r) {
              if (r.isEmpty) {
                return const Center(
                  child: Card(
                    child: ListTile(
                      leading: Icon(Icons.verified, color: AppColors.success),
                      title: Text('No tracks need metadata review. 🎉'),
                    ),
                  ),
                );
              }
              return _body(r);
            },
          ),
        ),
      ],
    );
  }

  Widget _body(MetadataReviewReport r) {
    final songs = r.needsReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary counts by gap type.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stat('Needs review', songs.length, AppColors.warning),
            _stat('Missing artist', r.missingArtist.length, AppColors.error),
            _stat('Missing album', r.missingAlbum.length, AppColors.error),
            _stat('Missing region', r.missingRegion.length, AppColors.error),
            _stat('Missing language', r.missingLanguage.length, AppColors.error),
            _stat('Missing genre', r.missingGenre.length, AppColors.info),
            _stat('Missing artwork', r.missingArtwork.length, AppColors.info),
          ],
        ),
        const SizedBox(height: 12),
        // Bulk action bar.
        Row(
          children: [
            TextButton.icon(
              onPressed: songs.isEmpty
                  ? null
                  : () => setState(() {
                        if (_selected.length == songs.length) {
                          _selected.clear();
                        } else {
                          _selected
                            ..clear()
                            ..addAll(songs.map((s) => s.id));
                        }
                      }),
              icon: const Icon(Icons.select_all),
              label: Text(_selected.length == songs.length
                  ? 'Clear selection'
                  : 'Select all (${songs.length})'),
            ),
            const Spacer(),
            Text('${_selected.length} selected'),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: (_selected.isEmpty || _busy)
                  ? null
                  : () => _openBulkEdit(songs),
              icon: _busy
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.edit_note),
              label: const Text('Bulk Edit'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              itemCount: songs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _row(songs[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat(String label, int n, Color color) => _pill('$label: $n', color);

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );

  Widget _row(Song s) {
    final gaps = <String>[
      if (s.artistName.isEmpty || s.artistName == 'Unknown Artist') 'artist',
      if (s.albumTitle.isEmpty || s.albumTitle == 'Imported Recordings') 'album',
      if (s.region.isEmpty || s.region == ContentConstants.needsReview) 'region',
      if (s.language.isEmpty || s.language == ContentConstants.needsReview)
        'language',
      if (s.genre.isEmpty) 'genre',
      if (s.artworkUrl.isEmpty) 'artwork',
    ];
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: _selected.contains(s.id),
      onChanged: (v) => setState(() {
        if (v == true) {
          _selected.add(s.id);
        } else {
          _selected.remove(s.id);
        }
      }),
      title: Text(s.title, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${s.artistName} · ${s.albumTitle.isEmpty ? "—" : s.albumTitle} · '
        '${s.region}/${s.language} · ${s.durationFormatted}'
        '${gaps.isEmpty ? "" : "  ·  missing: ${gaps.join(", ")}"}',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _openBulkEdit(List<Song> all) async {
    final selectedSongs =
        all.where((s) => _selected.contains(s.id)).toList(growable: false);
    if (selectedSongs.isEmpty) return;

    final assignment = await showDialog<_BulkAssignment>(
      context: context,
      builder: (_) => _BulkEditDialog(count: selectedSongs.length),
    );
    if (assignment == null || assignment.isEmpty) return;

    await _applyBulk(selectedSongs, assignment);
  }

  Future<void> _applyBulk(List<Song> songs, _BulkAssignment a) async {
    setState(() => _busy = true);
    final songDs = ref.read(adminSongDsProvider);
    final artistDs = ref.read(adminArtistDsProvider);
    final albumDs = ref.read(adminAlbumDsProvider);

    final existingArtistIds =
        (await ref.read(adminArtistsProvider.future)).map((x) => x.id).toSet();
    final existingAlbumIds =
        (await ref.read(adminAlbumsProvider.future)).map((x) => x.id).toSet();

    final newArtists = <String, Artist>{};
    final newAlbums = <String, Album>{};

    try {
      for (final s in songs) {
        var updated = s;

        // Reassign artist (recompute id + ensure the artist doc exists).
        if (a.artist != null && a.artist!.isNotEmpty) {
          final aid = MetadataValidator.artistId(a.artist!);
          updated = updated.copyWith(artistName: a.artist, artistId: aid);
          if (!existingArtistIds.contains(aid) &&
              !newArtists.containsKey(aid)) {
            newArtists[aid] = Artist(
              id: aid,
              name: a.artist!,
              imageUrl: s.artworkUrl,
              region: a.region ?? s.region,
              bio: '${a.artist} — imported into HimRaag.',
              songCount: 0,
              albumCount: 0,
              genres: [a.genre ?? s.genre],
              approvalStatus: ApprovalStatus.approved,
              isPublished: true,
              slug: MetadataValidator.slugify(a.artist!),
            );
          }
        }

        // Reassign album (recompute id + ensure the album doc exists).
        if (a.album != null && a.album!.isNotEmpty) {
          final artistName = updated.artistName;
          final albId = MetadataValidator.albumId(artistName, a.album!);
          updated = updated.copyWith(albumTitle: a.album, albumId: albId);
          if (!existingAlbumIds.contains(albId) &&
              !newAlbums.containsKey(albId)) {
            newAlbums[albId] = Album(
              id: albId,
              title: a.album!,
              artistId: updated.artistId,
              artistName: artistName,
              artworkUrl: s.artworkUrl,
              region: a.region ?? s.region,
              language: a.language ?? s.language,
              genre: a.genre ?? s.genre,
              releaseYear: s.releaseYear,
              songCount: 0,
              totalDuration: Duration.zero,
              license: s.license,
              attribution: s.attribution,
              approvalStatus: ApprovalStatus.approved,
              isPublished: true,
              rightsCleared: s.rightsCleared,
              slug: MetadataValidator.slugify(a.album!),
            );
          }
        }

        if (a.region != null) updated = updated.copyWith(region: a.region);
        if (a.language != null) updated = updated.copyWith(language: a.language);
        if (a.genre != null) updated = updated.copyWith(genre: a.genre);

        // Drop the review tag once region/language/artist are all resolved.
        final resolved = updated.region != ContentConstants.needsReview &&
            updated.region.isNotEmpty &&
            updated.language != ContentConstants.needsReview &&
            updated.language.isNotEmpty &&
            updated.artistName.isNotEmpty &&
            updated.artistName != 'Unknown Artist';
        if (resolved && updated.tags.contains(ContentConstants.needsReviewTag)) {
          updated = updated.copyWith(
            tags: updated.tags
                .where((t) => t != ContentConstants.needsReviewTag)
                .toList(),
          );
        }

        await songDs.upsertSong(updated);
      }

      for (final art in newArtists.values) {
        await artistDs.upsertArtist(art);
      }
      for (final alb in newAlbums.values) {
        await albumDs.upsertAlbum(alb);
      }

      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
            action: 'bulk_metadata_edit',
            entityType: 'song',
            entityId: 'bulk-${DateTime.now().toIso8601String()}',
            actor: actor,
            detail: '${songs.length} songs · ${a.summary()}',
          );

      refreshCatalog(ref);
      ref.invalidate(metadataReviewProvider);
      if (mounted) {
        showSnack(context, 'Updated ${songs.length} song(s).');
        setState(() => _selected.clear());
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Bulk edit failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The values chosen in the bulk-edit dialog. A null field is left unchanged.
class _BulkAssignment {
  _BulkAssignment({
    this.artist,
    this.album,
    this.language,
    this.region,
    this.genre,
  });

  final String? artist;
  final String? album;
  final String? language;
  final String? region;
  final String? genre;

  bool get isEmpty =>
      artist == null &&
      album == null &&
      language == null &&
      region == null &&
      genre == null;

  String summary() {
    final parts = <String>[
      if (artist != null) 'artist=$artist',
      if (album != null) 'album=$album',
      if (region != null) 'region=$region',
      if (language != null) 'language=$language',
      if (genre != null) 'genre=$genre',
    ];
    return parts.join(', ');
  }
}

class _BulkEditDialog extends StatefulWidget {
  const _BulkEditDialog({required this.count});

  final int count;

  @override
  State<_BulkEditDialog> createState() => _BulkEditDialogState();
}

class _BulkEditDialogState extends State<_BulkEditDialog> {
  final _artist = TextEditingController();
  final _album = TextEditingController();
  String? _region;
  String? _language;
  String? _genre;

  @override
  void dispose() {
    _artist.dispose();
    _album.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bulk edit ${widget.count} song(s)'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Only the fields you set are applied. Leave blank to '
                  'keep existing values.'),
              const SizedBox(height: 16),
              TextField(
                controller: _artist,
                decoration: const InputDecoration(
                  labelText: 'Assign artist',
                  hintText: 'e.g. Diksha Dhaundiyal',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _album,
                decoration: const InputDecoration(
                  labelText: 'Assign album',
                  hintText: 'e.g. Kumaoni Folk Vol. 1',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              _dropdown('Assign region', _region, AppConstants.pahadiRegions,
                  (v) => setState(() => _region = v)),
              const SizedBox(height: 12),
              _dropdown('Assign language', _language,
                  ContentConstants.languages, (v) => setState(() => _language = v)),
              const SizedBox(height: 12),
              _dropdown('Assign genre', _genre, AppConstants.pahadiGenres,
                  (v) => setState(() => _genre = v)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final artist = _artist.text.trim();
            final album = _album.text.trim();
            Navigator.pop(
              context,
              _BulkAssignment(
                artist: artist.isEmpty ? null : artist,
                album: album.isEmpty ? null : album,
                region: _region,
                language: _language,
                genre: _genre,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String? value, List<String> items,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        const DropdownMenuItem(value: null, child: Text('— keep —')),
        ...items.map((i) => DropdownMenuItem(value: i, child: Text(i))),
      ],
      onChanged: onChanged,
    );
  }
}
