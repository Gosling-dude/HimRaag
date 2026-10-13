import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/remote/firebase_song_request_datasource.dart';
import '../auth/providers/auth_providers.dart';
import '../home/providers/home_providers.dart';

final songRequestDatasourceProvider =
    Provider<FirebaseSongRequestDatasource>((ref) {
  return FirebaseSongRequestDatasource(ref.watch(firestoreProvider));
});

/// Opens the "Request a song" form. [searchQuery] (what the listener was
/// searching for) pre-fills the song name.
Future<void> showSongRequestSheet(BuildContext context,
    {String searchQuery = ''}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceDark,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SongRequestSheet(searchQuery: searchQuery),
  );
}

/// Whether [value] is empty or looks like a web link.
bool isValidRequestLink(String value) {
  final v = value.trim();
  if (v.isEmpty) return true;
  final uri = Uri.tryParse(v.contains('://') ? v : 'https://$v');
  return uri != null && uri.host.contains('.') && !v.contains(' ');
}

class SongRequestSheet extends ConsumerStatefulWidget {
  const SongRequestSheet({super.key, this.searchQuery = ''});

  final String searchQuery;

  @override
  ConsumerState<SongRequestSheet> createState() => _SongRequestSheetState();
}

class _SongRequestSheetState extends ConsumerState<SongRequestSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title =
      TextEditingController(text: widget.searchQuery.trim());
  final _artist = TextEditingController();
  final _link = TextEditingController();
  final _details = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _link.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Please sign in to request a song.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(songRequestDatasourceProvider).submit(
            songTitle: _title.text,
            artist: _artist.text,
            link: _link.text,
            details: _details.text,
            searchQuery: widget.searchQuery,
            userId: user.uid,
            userName: user.displayName ?? '',
            userEmail: user.email ?? '',
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
          content: Text("Thanks! We'll try to add this song soon.")));
    } catch (e) {
      debugPrint('[REQUEST] submit failed: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't send your request. Please try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dividerDark,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Request a song', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "Tell us what you'd like to hear and we'll try to add it.",
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondaryDark),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.words,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Song name *',
                  counterText: '',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the song name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _artist,
                textCapitalization: TextCapitalization.words,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Singer / artist (optional)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _link,
                keyboardType: TextInputType.url,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'YouTube or other link (optional)',
                  hintText: 'https://youtube.com/…',
                  counterText: '',
                ),
                validator: (v) =>
                    isValidRequestLink(v ?? '') ? null : 'Enter a valid link',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _details,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Anything else? (optional)',
                  hintText: 'Album, year, lyrics you remember…',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send request'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
