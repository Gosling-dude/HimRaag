import 'package:equatable/equatable.dart';

import '../../core/constants/content_constants.dart';

class Song extends Equatable {
  const Song({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.albumId,
    required this.albumTitle,
    required this.audioUrl,
    required this.artworkUrl,
    required this.duration,
    required this.region,
    required this.language,
    required this.genre,
    required this.releaseYear,
    required this.playCount,
    required this.tags,
    required this.isApproved,
    required this.isDownloadable,
    this.lyrics,
    this.mood,
    this.albumArtist,
    this.localPath,
    this.slug = '',
    this.license = LicenseType.demoOnly,
    this.attribution = '',
    this.licenseUrl,
    this.sourceUrl,
    this.approvalStatus = ApprovalStatus.pending,
    this.isPublished = false,
    this.rightsCleared = false,
    this.reviewRequired = false,
    this.submittedBy,
  });

  final String id;
  final String title;
  final String artistId;
  final String artistName;
  final String albumId;
  final String albumTitle;
  final String audioUrl;
  final String artworkUrl;
  final Duration duration;
  final String region;
  final String language;
  final String genre;
  final int releaseYear;
  final int playCount;
  final List<String> tags;
  final bool isApproved;
  final bool isDownloadable;
  final String? lyrics;
  final String? mood;
  final String? albumArtist;
  final String? localPath;

  // ── Content-system metadata (licensing, moderation, provenance) ──────────
  final String slug;
  final LicenseType license;

  /// Exact attribution text, stored verbatim. Required for licenses where
  /// [LicenseType.requiresAttribution] is true.
  final String attribution;
  final String? licenseUrl;
  final String? sourceUrl;
  final ApprovalStatus approvalStatus;

  /// Public visibility gate. Demo content is always false.
  final bool isPublished;
  final bool rightsCleared;

  /// True when imported content still needs owner metadata review. Surfaces the
  /// track in the Admin Dashboard → Metadata Review queue.
  final bool reviewRequired;

  /// UID of the artist/admin who submitted the track, when applicable.
  final String? submittedBy;

  /// True only for placeholder content that must never be published.
  bool get isDemo => license == LicenseType.demoOnly;

  bool get isDownloaded => localPath != null;

  String get durationFormatted {
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Song copyWith({
    String? id,
    String? title,
    String? artistId,
    String? artistName,
    String? albumId,
    String? albumTitle,
    String? audioUrl,
    String? artworkUrl,
    Duration? duration,
    String? region,
    String? language,
    String? genre,
    int? releaseYear,
    int? playCount,
    List<String>? tags,
    bool? isApproved,
    bool? isDownloadable,
    String? lyrics,
    String? mood,
    String? albumArtist,
    String? localPath,
    String? slug,
    LicenseType? license,
    String? attribution,
    String? licenseUrl,
    String? sourceUrl,
    ApprovalStatus? approvalStatus,
    bool? isPublished,
    bool? rightsCleared,
    bool? reviewRequired,
    String? submittedBy,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      albumId: albumId ?? this.albumId,
      albumTitle: albumTitle ?? this.albumTitle,
      audioUrl: audioUrl ?? this.audioUrl,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      duration: duration ?? this.duration,
      region: region ?? this.region,
      language: language ?? this.language,
      genre: genre ?? this.genre,
      releaseYear: releaseYear ?? this.releaseYear,
      playCount: playCount ?? this.playCount,
      tags: tags ?? this.tags,
      isApproved: isApproved ?? this.isApproved,
      isDownloadable: isDownloadable ?? this.isDownloadable,
      lyrics: lyrics ?? this.lyrics,
      mood: mood ?? this.mood,
      albumArtist: albumArtist ?? this.albumArtist,
      localPath: localPath ?? this.localPath,
      slug: slug ?? this.slug,
      license: license ?? this.license,
      attribution: attribution ?? this.attribution,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      isPublished: isPublished ?? this.isPublished,
      rightsCleared: rightsCleared ?? this.rightsCleared,
      reviewRequired: reviewRequired ?? this.reviewRequired,
      submittedBy: submittedBy ?? this.submittedBy,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artistId,
        artistName,
        albumId,
        albumTitle,
        audioUrl,
        artworkUrl,
        duration,
        region,
        language,
        genre,
        releaseYear,
        playCount,
        tags,
        isApproved,
        isDownloadable,
        lyrics,
        mood,
        albumArtist,
        localPath,
        slug,
        license,
        attribution,
        licenseUrl,
        sourceUrl,
        approvalStatus,
        isPublished,
        rightsCleared,
        reviewRequired,
        submittedBy,
      ];
}
