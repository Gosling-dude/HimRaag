import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../admin/admin_auth.dart';
import '../admin/admin_providers.dart';
import '../admin/admin_widgets.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/content_constants.dart';
import '../core/theme/app_colors.dart';
import '../data/remote/firebase_album_datasource.dart';
import '../data/remote/firebase_artist_datasource.dart';
import '../data/remote/firebase_song_datasource.dart';
import '../data/remote/firebase_submission_datasource.dart';
import '../domain/models/album.dart';
import '../domain/models/artist.dart';
import '../domain/models/song.dart';
import '../domain/models/submission.dart';

// ── Artist-scoped providers (keyed off the signed-in artist's uid) ───────────

final _artistDsProvider = Provider(
    (ref) => FirebaseArtistDatasource(ref.watch(adminFirestoreProvider)));
final _songDsProvider = Provider(
    (ref) => FirebaseSongDatasource(ref.watch(adminFirestoreProvider)));
final _albumDsProvider = Provider(
    (ref) => FirebaseAlbumDatasource(ref.watch(adminFirestoreProvider)));
final _submissionDsProvider = Provider(
    (ref) => FirebaseSubmissionDatasource(ref.watch(adminFirestoreProvider)));

final _myProfileProvider = FutureProvider.family<Artist?, String>(
    (ref, uid) => ref.watch(_artistDsProvider).getArtistByOwner(uid));

final _myAlbumsProvider = FutureProvider.family<List<Album>, String>(
    (ref, artistId) => ref.watch(_albumDsProvider).getAlbumsByArtist(artistId));

final _mySongsProvider = FutureProvider.family<List<Song>, String>(
    (ref, artistId) => ref.watch(_songDsProvider).getSongsByArtist(artistId));

final _mySubmissionsProvider = FutureProvider.family<List<Submission>, String>(
    (ref, uid) => ref.watch(_submissionDsProvider).getByOwner(uid));

/// Contributor dashboard: profile + bio management, album/track lists,
/// submission status, the future-upload workflow, and a rights/permission note.
class ArtistDashboard extends ConsumerWidget {
  const ArtistDashboard({super.key, required this.session});

  final AdminSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_myProfileProvider(session.uid));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artist Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out (${session.email})',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(adminAuthControllerProvider).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load profile: $e')),
        data: (profile) {
          if (profile == null) {
            return _NoProfile(email: session.email);
          }
          return _ArtistBody(session: session, profile: profile);
        },
      ),
    );
  }
}

class _NoProfile extends StatelessWidget {
  const _NoProfile({required this.email});
  final String email;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 56, color: AppColors.warning),
              const SizedBox(height: 16),
              Text('No artist profile linked',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Your account ($email) has the artist role but no artist '
                'profile is linked yet. An admin must set ownerUid on your '
                'artist document to this account, then reload.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArtistBody extends ConsumerWidget {
  const _ArtistBody({required this.session, required this.profile});

  final AdminSession session;
  final Artist profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(_myAlbumsProvider(profile.id));
    final songs = ref.watch(_mySongsProvider(profile.id));
    final subs = ref.watch(_mySubmissionsProvider(session.uid));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProfileCard(profile: profile),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: _ListCard(
                    title: 'Albums',
                    icon: Icons.album,
                    child: albums.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Failed: $e'),
                      data: (list) => list.isEmpty
                          ? const Text('No albums yet.')
                          : Column(
                              children: list
                                  .map((a) => ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.album_outlined),
                                        title: Text(a.title),
                                        subtitle: Text(
                                            '${a.songCount} tracks · ${a.releaseYear}'),
                                        trailing: StatusChip(a.approvalStatus),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ListCard(
                    title: 'Tracks',
                    icon: Icons.music_note,
                    child: songs.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => Text('Failed: $e'),
                      data: (list) => list.isEmpty
                          ? const Text('No tracks yet.')
                          : Column(
                              children: list
                                  .take(20)
                                  .map((s) => ListTile(
                                        dense: true,
                                        leading: const Icon(Icons.audiotrack),
                                        title: Text(s.title),
                                        subtitle: Text(s.durationFormatted),
                                        trailing: StatusChip(s.approvalStatus),
                                      ))
                                  .toList(),
                            ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _SubmissionsCard(session: session, profile: profile, subs: subs),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard({required this.profile});
  final Artist profile;

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  late final TextEditingController _bio;
  late final TextEditingController _rights;
  late final TextEditingController _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _bio = TextEditingController(text: widget.profile.bio);
    _rights = TextEditingController(text: widget.profile.rightsNote);
    _image = TextEditingController(text: widget.profile.imageUrl);
  }

  @override
  void dispose() {
    _bio.dispose();
    _rights.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Only fields the artist owns are changed; moderation fields are
      // preserved (and the security rules reject changes to them).
      final updated = widget.profile.copyWith(
        bio: _bio.text.trim(),
        rightsNote: _rights.text.trim(),
        imageUrl: _image.text.trim(),
      );
      await ref.read(_artistDsProvider).upsertArtist(updated);
      ref.invalidate(_myProfileProvider(widget.profile.ownerUid ?? ''));
      if (mounted) showSnack(context, 'Profile saved.');
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              CircleAvatar(
                  radius: 28,
                  child: Text(p.name.isNotEmpty ? p.name[0] : '?')),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('${p.region} · ${p.songCount} songs'),
                  ],
                ),
              ),
              StatusChip(p.approvalStatus),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _image,
              decoration: const InputDecoration(
                  labelText: 'Profile image URL', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rights,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Rights / permission note',
                helperText:
                    'State exactly how your tracks may be used (stored verbatim).',
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: const Text('Save profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionsCard extends ConsumerWidget {
  const _SubmissionsCard(
      {required this.session, required this.profile, required this.subs});

  final AdminSession session;
  final Artist profile;
  final AsyncValue<List<Submission>> subs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _ListCard(
      title: 'Submissions',
      icon: Icons.inbox,
      trailing: FilledButton.icon(
        onPressed: () => _newSubmission(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New submission'),
      ),
      child: subs.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('Failed: $e'),
        data: (list) => list.isEmpty
            ? const Text('No submissions yet. Use “New submission” to propose a '
                'track for review.')
            : Column(
                children: list
                    .map((s) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.description_outlined),
                          title: Text(s.title),
                          subtitle: Text(s.region),
                          trailing: _subStatusChip(s.status),
                        ))
                    .toList(),
              ),
      ),
    );
  }

  Widget _subStatusChip(String status) {
    final color = switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };
    return Chip(
      label: Text(status, style: TextStyle(color: color, fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
    );
  }

  Future<void> _newSubmission(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _SubmissionDialog(session: session, profile: profile),
    );
    if (created == true) {
      ref.invalidate(_mySubmissionsProvider(session.uid));
    }
  }
}

class _SubmissionDialog extends ConsumerStatefulWidget {
  const _SubmissionDialog({required this.session, required this.profile});
  final AdminSession session;
  final Artist profile;

  @override
  ConsumerState<_SubmissionDialog> createState() => _SubmissionDialogState();
}

class _SubmissionDialogState extends ConsumerState<_SubmissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _album = TextEditingController();
  final _audio = TextEditingController();
  final _art = TextEditingController();
  final _rights = TextEditingController();
  late String _region = widget.profile.region.isNotEmpty
      ? widget.profile.region
      : AppConstants.pahadiRegions.first;
  late String _language = widget.profile.region.isNotEmpty
      ? widget.profile.region
      : ContentConstants.languages.first;
  String _genre = AppConstants.pahadiGenres.first;
  String _license = LicenseType.permissionGranted.wire;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _album.dispose();
    _audio.dispose();
    _art.dispose();
    _rights.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(_submissionDsProvider).create(
            submittedBy: widget.session.uid,
            artistName: widget.profile.name,
            title: _title.text.trim(),
            region: _region,
            language: _language,
            genre: _genre,
            albumTitle: _album.text.trim(),
            audioUrl: _audio.text.trim(),
            artworkUrl: _art.text.trim(),
            license: _license,
            rightsNote: _rights.text.trim(),
          );
      if (mounted) {
        Navigator.pop(context, true);
        showSnack(context, 'Submission sent for review.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New track submission'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(_title, 'Track title *', required: true),
                _field(_album, 'Album (optional)'),
                _field(_audio, 'Audio URL', url: true),
                _field(_art, 'Cover art URL', url: true),
                Row(children: [
                  Expanded(
                      child: _dd('Region', _region, AppConstants.pahadiRegions,
                          (v) => setState(() => _region = v))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _dd('Language', _language,
                          ContentConstants.languages, (v) => setState(() => _language = v))),
                ]),
                Row(children: [
                  Expanded(
                      child: _dd('Genre', _genre, AppConstants.pahadiGenres,
                          (v) => setState(() => _genre = v))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _dd(
                          'License',
                          _license,
                          LicenseType.values
                              .where((l) => l != LicenseType.demoOnly)
                              .map((l) => l.wire)
                              .toList(),
                          (v) => setState(() => _license = v))),
                ]),
                _field(_rights, 'Rights / permission note *',
                    required: true, maxLines: 2),
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
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, bool url = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, isDense: true),
        validator: (v) {
          final val = (v ?? '').trim();
          if (required && val.isEmpty) return 'Required';
          if (url && val.isNotEmpty && !RegExp(r'^https?://.+').hasMatch(val)) {
            return 'Must be an http(s) URL';
          }
          return null;
        },
      ),
    );
  }

  Widget _dd(String label, String value, List<String> items,
      ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
      onChanged: (v) => onChanged(v ?? value),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (trailing != null) trailing!,
            ]),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}
