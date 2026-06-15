import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/remote/firebase_album_datasource.dart';
import '../data/remote/firebase_artist_datasource.dart';
import '../data/remote/firebase_audit_datasource.dart';
import '../data/remote/firebase_song_datasource.dart';
import '../data/remote/firebase_submission_datasource.dart';
import '../domain/models/album.dart';
import '../domain/models/artist.dart';
import '../domain/models/song.dart';
import '../domain/models/submission.dart';

// ── Datasources (reuse the consumer app's datasources) ──────────────────────

final adminFirestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final adminSongDsProvider = Provider(
    (ref) => FirebaseSongDatasource(ref.watch(adminFirestoreProvider)));
final adminAlbumDsProvider = Provider(
    (ref) => FirebaseAlbumDatasource(ref.watch(adminFirestoreProvider)));
final adminArtistDsProvider = Provider(
    (ref) => FirebaseArtistDatasource(ref.watch(adminFirestoreProvider)));
final adminSubmissionDsProvider = Provider(
    (ref) => FirebaseSubmissionDatasource(ref.watch(adminFirestoreProvider)));
final adminAuditDsProvider = Provider(
    (ref) => FirebaseAuditDatasource(ref.watch(adminFirestoreProvider)));

// ── Catalog data (admin view — unfiltered) ──────────────────────────────────

final adminSongsProvider = FutureProvider<List<Song>>(
    (ref) => ref.watch(adminSongDsProvider).getAllSongsForAdmin(limit: 500));

final adminAlbumsProvider = FutureProvider<List<Album>>(
    (ref) => ref.watch(adminAlbumDsProvider).getAllAlbumsForAdmin(limit: 500));

final adminArtistsProvider = FutureProvider<List<Artist>>(
    (ref) => ref.watch(adminArtistDsProvider).getAllArtistsForAdmin(limit: 500));

final pendingSubmissionsProvider = FutureProvider<List<Submission>>(
    (ref) => ref.watch(adminSubmissionDsProvider).getByStatus('pending'));

final auditLogProvider = FutureProvider<List<AuditEntry>>(
    (ref) => ref.watch(adminAuditDsProvider).recent());

/// Invalidate all catalog lists after a write so tables reflect changes.
void refreshCatalog(WidgetRef ref) {
  ref.invalidate(adminSongsProvider);
  ref.invalidate(adminAlbumsProvider);
  ref.invalidate(adminArtistsProvider);
  ref.invalidate(pendingSubmissionsProvider);
  ref.invalidate(auditLogProvider);
}

// ── Data-quality report (derived) ───────────────────────────────────────────

class DataQualityReport {
  DataQualityReport({
    required this.missingArtwork,
    required this.missingLyrics,
    required this.zeroDuration,
    required this.duplicates,
    required this.orphanArtist,
    required this.orphanAlbum,
    required this.rightsIssues,
  });

  final List<Song> missingArtwork;
  final List<Song> missingLyrics;
  final List<Song> zeroDuration;
  final List<String> duplicates;
  final List<Song> orphanArtist;
  final List<Song> orphanAlbum;
  final List<Song> rightsIssues;

  int get total =>
      missingArtwork.length +
      missingLyrics.length +
      zeroDuration.length +
      duplicates.length +
      orphanArtist.length +
      orphanAlbum.length +
      rightsIssues.length;
}

/// Computes the same data-quality report as `scripts/validate_catalog.js`
/// (minus the network reachability checks, which run in the Node tool).
final dataQualityProvider = FutureProvider<DataQualityReport>((ref) async {
  final songs = await ref.watch(adminSongsProvider.future);
  final albums = await ref.watch(adminAlbumsProvider.future);
  final artists = await ref.watch(adminArtistsProvider.future);

  final albumIds = albums.map((a) => a.id).toSet();
  final artistIds = artists.map((a) => a.id).toSet();

  final seen = <String, String>{};
  final duplicates = <String>[];
  final missingArtwork = <Song>[];
  final missingLyrics = <Song>[];
  final zeroDuration = <Song>[];
  final orphanArtist = <Song>[];
  final orphanAlbum = <Song>[];
  final rightsIssues = <Song>[];

  for (final s in songs) {
    if (s.artworkUrl.isEmpty) missingArtwork.add(s);
    if ((s.lyrics ?? '').trim().isEmpty) missingLyrics.add(s);
    if (s.duration.inMilliseconds <= 0) zeroDuration.add(s);
    if (s.artistId.isNotEmpty && !artistIds.contains(s.artistId)) {
      orphanArtist.add(s);
    }
    if (s.albumId.isNotEmpty && !albumIds.contains(s.albumId)) {
      orphanAlbum.add(s);
    }
    if (s.isPublished && !s.license.cleared) rightsIssues.add(s);

    final key = '${s.artistName.toLowerCase()}|${s.title.toLowerCase()}';
    if (seen.containsKey(key)) {
      duplicates.add('${s.id} ↔ ${seen[key]}');
    } else {
      seen[key] = s.id;
    }
  }

  return DataQualityReport(
    missingArtwork: missingArtwork,
    missingLyrics: missingLyrics,
    zeroDuration: zeroDuration,
    duplicates: duplicates,
    orphanArtist: orphanArtist,
    orphanAlbum: orphanAlbum,
    rightsIssues: rightsIssues,
  );
});
