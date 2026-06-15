import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/content_constants.dart';
import '../../core/validation/metadata_validator.dart';
import '../../domain/models/song.dart';
import '../admin_auth.dart';
import '../admin_providers.dart';
import '../admin_widgets.dart';

/// Create/edit a song with full content metadata. Validates client-side via
/// [MetadataValidator] rules (enforced through the form) before writing.
class SongEditorDialog extends ConsumerStatefulWidget {
  const SongEditorDialog({super.key, this.existing});

  /// Null → create mode.
  final Song? existing;

  static Future<bool?> show(BuildContext context, {Song? existing}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => SongEditorDialog(existing: existing),
    );
  }

  @override
  ConsumerState<SongEditorDialog> createState() => _SongEditorDialogState();
}

class _SongEditorDialogState extends ConsumerState<SongEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  late String _region;
  late String _language;
  late String _genre;
  late LicenseType _license;
  late ApprovalStatus _status;
  late bool _isDownloadable;
  late bool _isPublished;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _c = {
      'title': TextEditingController(text: s?.title ?? ''),
      'artistName': TextEditingController(text: s?.artistName ?? ''),
      'albumTitle': TextEditingController(text: s?.albumTitle ?? ''),
      'audioUrl': TextEditingController(text: s?.audioUrl ?? ''),
      'artworkUrl': TextEditingController(text: s?.artworkUrl ?? ''),
      'durationSec': TextEditingController(
          text: s != null ? s.duration.inSeconds.toString() : ''),
      'releaseYear': TextEditingController(
          text: (s?.releaseYear ?? DateTime.now().year).toString()),
      'tags': TextEditingController(text: s?.tags.join(', ') ?? ''),
      'mood': TextEditingController(text: s?.mood ?? ''),
      'lyrics': TextEditingController(text: s?.lyrics ?? ''),
      'attribution': TextEditingController(text: s?.attribution ?? ''),
      'sourceUrl': TextEditingController(text: s?.sourceUrl ?? ''),
      'licenseUrl': TextEditingController(text: s?.licenseUrl ?? ''),
    };
    _region = s?.region.isNotEmpty == true ? s!.region : AppConstants.pahadiRegions.first;
    _language = s?.language.isNotEmpty == true ? s!.language : ContentConstants.languages.first;
    _genre = s?.genre.isNotEmpty == true ? s!.genre : AppConstants.pahadiGenres.first;
    _license = s?.license ?? LicenseType.demoOnly;
    _status = s?.approvalStatus ?? ApprovalStatus.pending;
    _isDownloadable = s?.isDownloadable ?? true;
    _isPublished = s?.isPublished ?? false;
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String k) => _c[k]!.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Cross-field rights rule, mirrors the validator.
    if (_license.requiresAttribution && _t('attribution').isEmpty) {
      showSnack(context, 'License ${_license.wire} requires an attribution.',
          error: true);
      return;
    }
    if (_license == LicenseType.demoOnly && _isPublished) {
      showSnack(context, 'DEMO_ONLY content cannot be published.', error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final title = _t('title');
      final artistName = _t('artistName');
      final albumTitle = _t('albumTitle');
      final id = existing?.id ??
          MetadataValidator.songId(artistName, title);
      final artistId = existing?.artistId ??
          MetadataValidator.artistId(artistName);
      final albumId = existing?.albumId ??
          (albumTitle.isEmpty
              ? ''
              : MetadataValidator.albumId(artistName, albumTitle));

      final song = Song(
        id: id,
        title: title,
        artistId: artistId,
        artistName: artistName,
        albumId: albumId,
        albumTitle: albumTitle,
        audioUrl: _t('audioUrl'),
        artworkUrl: _t('artworkUrl'),
        duration: Duration(seconds: int.tryParse(_t('durationSec')) ?? 0),
        region: _region,
        language: _language,
        genre: _genre,
        releaseYear: int.tryParse(_t('releaseYear')) ?? DateTime.now().year,
        playCount: existing?.playCount ?? 0,
        tags: _t('tags')
            .split(RegExp(r'[,;]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        isApproved: _status.isApproved,
        isDownloadable: _isDownloadable,
        lyrics: _t('lyrics').isEmpty ? null : _t('lyrics'),
        mood: _t('mood').isEmpty ? null : _t('mood'),
        slug: MetadataValidator.slugify(title),
        license: _license,
        attribution: _t('attribution'),
        licenseUrl: _t('licenseUrl').isEmpty ? null : _t('licenseUrl'),
        sourceUrl: _t('sourceUrl').isEmpty ? null : _t('sourceUrl'),
        approvalStatus: _status,
        isPublished: _isPublished,
        rightsCleared: _license.cleared,
      );

      await ref.read(adminSongDsProvider).upsertSong(song);
      final actor = ref.read(adminSessionProvider).valueOrNull?.email ?? 'admin';
      await ref.read(adminAuditDsProvider).log(
            action: existing == null ? 'create' : 'update',
            entityType: 'song',
            entityId: song.id,
            actor: actor,
            detail: song.title,
          );
      if (mounted) {
        Navigator.pop(context, true);
        showSnack(context, 'Saved "${song.title}".');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Song' : 'Edit Song'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _text('title', 'Title *', required: true),
                _text('artistName', 'Artist name *', required: true),
                _text('albumTitle', 'Album title'),
                _text('audioUrl', 'Audio URL *', required: true, url: true),
                _text('artworkUrl', 'Cover art URL *', required: true, url: true),
                Row(children: [
                  Expanded(child: _text('durationSec', 'Duration (sec) *', number: true, required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _text('releaseYear', 'Year', number: true)),
                ]),
                Row(children: [
                  Expanded(child: _dropdown('Region *', _region, AppConstants.pahadiRegions, (v) => setState(() => _region = v))),
                  const SizedBox(width: 12),
                  Expanded(child: _dropdown('Language *', _language, ContentConstants.languages, (v) => setState(() => _language = v))),
                ]),
                Row(children: [
                  Expanded(child: _dropdown('Genre *', _genre, AppConstants.pahadiGenres, (v) => setState(() => _genre = v))),
                  const SizedBox(width: 12),
                  Expanded(child: _text('mood', 'Mood')),
                ]),
                _text('tags', 'Tags (comma separated)'),
                _text('lyrics', 'Lyrics', maxLines: 4),
                const Divider(height: 28),
                Text('Rights & moderation',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _licenseDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _statusDropdown()),
                ]),
                _text('attribution', 'Attribution'
                    '${_license.requiresAttribution ? ' *' : ''}',
                    maxLines: 2),
                _text('sourceUrl', 'Source URL'),
                _text('licenseUrl', 'License URL'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Downloadable (offline allowed)'),
                  value: _isDownloadable,
                  onChanged: (v) => setState(() => _isDownloadable = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Published (public)'),
                  subtitle: const Text('Demo content must stay off.'),
                  value: _isPublished,
                  onChanged: _license == LicenseType.demoOnly
                      ? null
                      : (v) => setState(() => _isPublished = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _text(String key, String label,
      {bool required = false,
      bool number = false,
      bool url = false,
      int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: _c[key],
        maxLines: maxLines,
        keyboardType: number ? TextInputType.number : null,
        decoration: InputDecoration(labelText: label, isDense: true),
        validator: (v) {
          final val = (v ?? '').trim();
          if (required && val.isEmpty) return 'Required';
          if (url && val.isNotEmpty &&
              !RegExp(r'^https?://.+').hasMatch(val)) {
            return 'Must be an http(s) URL';
          }
          if (number && val.isNotEmpty && int.tryParse(val) == null) {
            return 'Must be a number';
          }
          if (key == 'durationSec' &&
              required &&
              (int.tryParse(val) ?? 0) <= 0) {
            return 'Must be > 0';
          }
          return null;
        },
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: items
            .map((i) => DropdownMenuItem(value: i, child: Text(i)))
            .toList(),
        onChanged: (v) => onChanged(v ?? value),
      ),
    );
  }

  Widget _licenseDropdown() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DropdownButtonFormField<LicenseType>(
          value: _license,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'License *', isDense: true),
          items: LicenseType.values
              .map((l) => DropdownMenuItem(value: l, child: Text(l.wire)))
              .toList(),
          onChanged: (v) => setState(() {
            _license = v ?? _license;
            if (_license == LicenseType.demoOnly) _isPublished = false;
          }),
        ),
      );

  Widget _statusDropdown() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: DropdownButtonFormField<ApprovalStatus>(
          value: _status,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Status *', isDense: true),
          items: ApprovalStatus.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.wire)))
              .toList(),
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
      );
}
