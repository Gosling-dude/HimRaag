import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/validation/metadata_validator.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import '../../core/constants/content_constants.dart';
import '../admin_auth.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Batch import: paste CSV or JSON, validate against the canonical rules
/// ([MetadataValidator]), preview per-row results, then commit valid records
/// (songs + derived artists/albums) to Firestore.
///
/// File upload is intentionally paste-based to stay dependency-free; the Node
/// `scripts/import.js` handles file/folder ingestion at scale.
class ImportSection extends ConsumerStatefulWidget {
  const ImportSection({super.key});

  @override
  ConsumerState<ImportSection> createState() => _ImportSectionState();
}

class _ImportSectionState extends ConsumerState<ImportSection> {
  final _input = TextEditingController();
  String _format = 'json';
  List<_Row>? _rows;
  Map<int, String> _dups = {};
  bool _committing = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parse() {
    final text = _input.text.trim();
    if (text.isEmpty) return [];
    if (_format == 'json') {
      final decoded = jsonDecode(text);
      final list = decoded is Map<String, dynamic>
          ? (decoded['songs'] as List? ?? [])
          : decoded as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return _parseCsv(text);
  }

  void _validate() {
    try {
      final raw = _parse();
      final results = raw
          .map((r) => MetadataValidator.validateTrack(r))
          .toList();
      final normalized = results.map((r) => r.normalized).toList();
      final dups = MetadataValidator.findDuplicates(normalized);
      setState(() {
        _rows = [
          for (var i = 0; i < results.length; i++)
            _Row(index: i, result: results[i]),
        ];
        _dups = dups;
      });
    } catch (e) {
      setState(() => _rows = null);
      showSnack(context, 'Parse error: $e', error: true);
    }
  }

  int get _validCount =>
      _rows == null
          ? 0
          : _rows!
              .where((r) => r.result.ok && !_dups.containsKey(r.index))
              .length;

  Future<void> _commit() async {
    final rows = _rows;
    if (rows == null) return;
    final committable = rows
        .where((r) => r.result.ok && !_dups.containsKey(r.index))
        .map((r) => r.result.normalized)
        .toList();
    if (committable.isEmpty) {
      showSnack(context, 'Nothing valid to commit.', error: true);
      return;
    }

    setState(() => _committing = true);
    try {
      final songDs = ref.read(adminSongDsProvider);
      final albumDs = ref.read(adminAlbumDsProvider);
      final artistDs = ref.read(adminArtistDsProvider);

      // Existing entities to avoid clobbering rich profiles.
      final existingArtists =
          (await ref.read(adminArtistsProvider.future)).map((a) => a.id).toSet();
      final existingAlbums =
          (await ref.read(adminAlbumsProvider.future)).map((a) => a.id).toSet();

      final newArtists = <String, Artist>{};
      final newAlbums = <String, Album>{};

      for (final m in committable) {
        final song = _toSong(m);
        await songDs.upsertSong(song);

        if (song.artistId.isNotEmpty &&
            !existingArtists.contains(song.artistId) &&
            !newArtists.containsKey(song.artistId)) {
          newArtists[song.artistId] = Artist(
            id: song.artistId,
            name: song.artistName,
            imageUrl: song.artworkUrl,
            region: song.region,
            bio: '${song.artistName} — ${song.region} artist.',
            songCount: 0,
            albumCount: 0,
            genres: [song.genre],
            approvalStatus: song.approvalStatus,
            isPublished: song.isPublished,
            slug: MetadataValidator.slugify(song.artistName),
          );
        }
        if (song.albumId.isNotEmpty &&
            !existingAlbums.contains(song.albumId) &&
            !newAlbums.containsKey(song.albumId)) {
          newAlbums[song.albumId] = Album(
            id: song.albumId,
            title: song.albumTitle,
            artistId: song.artistId,
            artistName: song.artistName,
            artworkUrl: song.artworkUrl,
            region: song.region,
            language: song.language,
            genre: song.genre,
            releaseYear: song.releaseYear,
            songCount: 0,
            totalDuration: Duration.zero,
            license: song.license,
            attribution: song.attribution,
            approvalStatus: song.approvalStatus,
            isPublished: song.isPublished,
            rightsCleared: song.rightsCleared,
            slug: MetadataValidator.slugify(song.albumTitle),
          );
        }
      }

      for (final a in newArtists.values) {
        await artistDs.upsertArtist(a);
      }
      for (final a in newAlbums.values) {
        await albumDs.upsertAlbum(a);
      }

      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
            action: 'bulk_import',
            entityType: 'batch',
            entityId: 'import-${DateTime.now().toIso8601String()}',
            actor: actor,
            detail: '${committable.length} songs, ${newAlbums.length} albums, '
                '${newArtists.length} artists',
          );

      refreshCatalog(ref);
      if (mounted) {
        showSnack(context,
            'Imported ${committable.length} songs, ${newAlbums.length} albums, ${newArtists.length} artists.');
        setState(() => _rows = null);
        _input.clear();
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  Song _toSong(Map<String, dynamic> m) {
    final license = LicenseType.fromWire(m['license'] as String?);
    return Song(
      id: m['id'] as String,
      title: m['title'] as String,
      artistId: m['artistId'] as String,
      artistName: m['artistName'] as String,
      albumId: (m['albumId'] as String?) ?? '',
      albumTitle: (m['albumTitle'] as String?) ?? '',
      audioUrl: m['audioUrl'] as String,
      artworkUrl: m['artworkUrl'] as String,
      duration: Duration(milliseconds: (m['durationMs'] as num).toInt()),
      region: m['region'] as String,
      language: m['language'] as String,
      genre: m['genre'] as String,
      releaseYear: (m['releaseYear'] as num).toInt(),
      playCount: (m['playCount'] as num?)?.toInt() ?? 0,
      tags: (m['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isApproved: ApprovalStatus.fromWire(m['approvalStatus'] as String?).isApproved,
      isDownloadable: m['isDownloadable'] != false,
      lyrics: (m['lyrics'] as String?)?.isNotEmpty == true ? m['lyrics'] as String : null,
      mood: (m['mood'] as String?)?.isNotEmpty == true ? m['mood'] as String : null,
      slug: (m['slug'] as String?) ?? '',
      license: license,
      attribution: (m['attribution'] as String?) ?? '',
      licenseUrl: m['licenseUrl'] as String?,
      sourceUrl: m['sourceUrl'] as String?,
      approvalStatus: ApprovalStatus.fromWire(m['approvalStatus'] as String?),
      isPublished: m['isPublished'] == true,
      rightsCleared: license.cleared,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Batch Import',
            subtitle:
                'Paste CSV or JSON. Records are validated against the canonical '
                'rules before anything is written.'),
        Row(children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'json', label: Text('JSON')),
              ButtonSegment(value: 'csv', label: Text('CSV')),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _validate,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Validate'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: (_validCount > 0 && !_committing) ? _commit : null,
            icon: _committing
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            label: Text('Commit $_validCount'),
          ),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: TextField(
            controller: _input,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: _format == 'json'
                  ? '{ "songs": [ { "title": "...", "artistName": "...", '
                      '"region": "Garhwali", "language": "Garhwali", '
                      '"genre": "Folk", "durationMs": 200000, '
                      '"audioUrl": "https://...", "artworkUrl": "https://...", '
                      '"license": "DEMO_ONLY", "approvalStatus": "demo" } ] }'
                  : 'title,artistName,region,language,genre,durationMs,audioUrl,'
                      'artworkUrl,license,approvalStatus\n'
                      'Bedu Pako,Traditional (Garhwali),Garhwali,Garhwali,Folk,'
                      '200000,https://...,https://...,DEMO_ONLY,demo',
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _results()),
      ],
    );
  }

  Widget _results() {
    final rows = _rows;
    if (rows == null) {
      return const Center(
          child: Text('Paste data and press Validate to preview.'));
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final r = rows[i];
          final dup = _dups[r.index];
          final ok = r.result.ok && dup == null;
          final m = r.result.normalized;
          return ListTile(
            leading: Icon(
              ok ? Icons.check_circle : Icons.error,
              color: ok ? AppColors.success : AppColors.error,
            ),
            title: Text('${m['title'] ?? '(row ${i + 1})'} — ${m['artistName'] ?? ''}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dup != null)
                  Text('Duplicate: $dup',
                      style: const TextStyle(color: AppColors.error)),
                ...r.result.errors
                    .map((e) => Text('• $e', style: const TextStyle(color: AppColors.error))),
                ...r.result.warnings
                    .map((w) => Text('• $w', style: const TextStyle(color: AppColors.warning))),
              ],
            ),
          );
        },
      ),
    );
  }

  // Minimal CSV parser mirroring scripts/import.js (handles quotes/commas).
  List<Map<String, dynamic>> _parseCsv(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (inQuotes) {
        if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else if (c == '"') {
          inQuotes = false;
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == ',') {
        row.add(field.toString());
        field.clear();
      } else if (c == '\r') {
        // ignore
      } else if (c == '\n') {
        row.add(field.toString());
        rows.add(row);
        row = [];
        field.clear();
      } else {
        field.write(c);
      }
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    if (rows.isEmpty) return [];
    final headers = rows.first.map((h) => h.trim()).toList();
    return rows
        .skip(1)
        .where((r) => r.any((c) => c.trim().isNotEmpty))
        .map((r) {
      final map = <String, dynamic>{};
      for (var i = 0; i < headers.length; i++) {
        map[headers[i]] = i < r.length ? r[i].trim() : '';
      }
      return map;
    }).toList();
  }
}

class _Row {
  _Row({required this.index, required this.result});
  final int index;
  final TrackValidationResult result;
}
