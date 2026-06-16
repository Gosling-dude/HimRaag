import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/content_constants.dart';
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

// ── Metadata-review queue (imported audio pending cleanup) ───────────────────

/// Buckets the tracks that still need metadata attention — primarily the
/// locally-imported audio (no embedded tags), but also any catalog song with a
/// gap. Drives the admin "Review" section and its bulk-edit tools.
class MetadataReviewReport {
  MetadataReviewReport({
    required this.needsReview,
    required this.missingArtist,
    required this.missingAlbum,
    required this.missingRegion,
    required this.missingLanguage,
    required this.missingGenre,
    required this.missingArtwork,
  });

  /// Every track flagged for review (union of all gaps + the review tag).
  final List<Song> needsReview;
  final List<Song> missingArtist;
  final List<Song> missingAlbum;
  final List<Song> missingRegion;
  final List<Song> missingLanguage;
  final List<Song> missingGenre;
  final List<Song> missingArtwork;

  bool get isEmpty => needsReview.isEmpty;
}

/// A song is "missing" a field when it is blank, a known placeholder, or the
/// `Needs Review` sentinel.
bool _missingArtist(Song s) =>
    s.artistName.trim().isEmpty || s.artistName == 'Unknown Artist';
bool _missingAlbum(Song s) =>
    s.albumTitle.trim().isEmpty || s.albumTitle == 'Imported Recordings';
bool _missingRegion(Song s) =>
    s.region.trim().isEmpty || s.region == ContentConstants.needsReview;
bool _missingLanguage(Song s) =>
    s.language.trim().isEmpty || s.language == ContentConstants.needsReview;
bool _missingGenre(Song s) => s.genre.trim().isEmpty;
bool _missingArt(Song s) => s.artworkUrl.trim().isEmpty;

final metadataReviewProvider = FutureProvider<MetadataReviewReport>((ref) async {
  final songs = await ref.watch(adminSongsProvider.future);

  bool flagged(Song s) =>
      s.tags.contains(ContentConstants.needsReviewTag) ||
      _missingArtist(s) ||
      _missingAlbum(s) ||
      _missingRegion(s) ||
      _missingLanguage(s) ||
      _missingGenre(s) ||
      _missingArt(s);

  return MetadataReviewReport(
    needsReview: songs.where(flagged).toList(),
    missingArtist: songs.where(_missingArtist).toList(),
    missingAlbum: songs.where(_missingAlbum).toList(),
    missingRegion: songs.where(_missingRegion).toList(),
    missingLanguage: songs.where(_missingLanguage).toList(),
    missingGenre: songs.where(_missingGenre).toList(),
    missingArtwork: songs.where(_missingArt).toList(),
  );
});
