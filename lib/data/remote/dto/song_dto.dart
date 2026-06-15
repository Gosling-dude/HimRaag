import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/content_constants.dart';
import '../../../domain/models/song.dart';

class SongDto {
  const SongDto({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.albumId,
    required this.albumTitle,
    required this.audioUrl,
    required this.artworkUrl,
    required this.durationMs,
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
    this.slug = '',
    this.license = 'DEMO_ONLY',
    this.attribution = '',
    this.licenseUrl,
    this.sourceUrl,
    this.approvalStatus = 'pending',
    this.isPublished = false,
    this.rightsCleared = false,
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
  final int durationMs;
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

  // ── Content-system metadata ──────────────────────────────────────────────
  final String slug;
  final String license;
  final String attribution;
  final String? licenseUrl;
  final String? sourceUrl;
  final String approvalStatus;
  final bool isPublished;
  final bool rightsCleared;
  final String? submittedBy;

  factory SongDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // Back-compat: older docs only carry `isApproved`. Derive approvalStatus
    // from it when the explicit field is absent.
    final rawStatus = data['approvalStatus'] as String?;
    final approvedFlag = data['isApproved'] as bool? ?? false;
    return SongDto(
      id: doc.id,
      title: data['title'] as String? ?? '',
      artistId: data['artistId'] as String? ?? '',
      artistName: data['artistName'] as String? ?? '',
      albumId: data['albumId'] as String? ?? '',
      albumTitle: data['albumTitle'] as String? ?? '',
      audioUrl: data['audioUrl'] as String? ?? '',
      artworkUrl: data['artworkUrl'] as String? ?? '',
      durationMs: data['durationMs'] as int? ?? 0,
      region: data['region'] as String? ?? '',
      language: data['language'] as String? ?? '',
      genre: data['genre'] as String? ?? '',
      releaseYear: data['releaseYear'] as int? ?? 2024,
      playCount: data['playCount'] as int? ?? 0,
      tags: List<String>.from(data['tags'] as List? ?? []),
      isApproved: approvedFlag,
      isDownloadable: data['isDownloadable'] as bool? ?? true,
      lyrics: data['lyrics'] as String?,
      mood: data['mood'] as String?,
      albumArtist: data['albumArtist'] as String?,
      slug: data['slug'] as String? ?? '',
      license: data['license'] as String? ?? 'DEMO_ONLY',
      attribution: data['attribution'] as String? ?? '',
      licenseUrl: data['licenseUrl'] as String?,
      sourceUrl: data['sourceUrl'] as String?,
      approvalStatus: rawStatus ?? (approvedFlag ? 'approved' : 'pending'),
      isPublished: data['isPublished'] as bool? ?? false,
      rightsCleared: data['rightsCleared'] as bool? ?? false,
      submittedBy: data['submittedBy'] as String?,
    );
  }

  Song toDomain({String? localPath}) => Song(
        id: id,
        title: title,
        artistId: artistId,
        artistName: artistName,
        albumId: albumId,
        albumTitle: albumTitle,
        audioUrl: audioUrl,
        artworkUrl: artworkUrl,
        duration: Duration(milliseconds: durationMs),
        region: region,
        language: language,
        genre: genre,
        releaseYear: releaseYear,
        playCount: playCount,
        tags: tags,
        isApproved: isApproved,
        isDownloadable: isDownloadable,
        lyrics: lyrics,
        mood: mood,
        albumArtist: albumArtist,
        localPath: localPath,
        slug: slug,
        license: LicenseType.fromWire(license),
        attribution: attribution,
        licenseUrl: licenseUrl,
        sourceUrl: sourceUrl,
        approvalStatus: ApprovalStatus.fromWire(approvalStatus),
        isPublished: isPublished,
        rightsCleared: rightsCleared,
        submittedBy: submittedBy,
      );

  factory SongDto.fromDomain(Song song) => SongDto(
        id: song.id,
        title: song.title,
        artistId: song.artistId,
        artistName: song.artistName,
        albumId: song.albumId,
        albumTitle: song.albumTitle,
        audioUrl: song.audioUrl,
        artworkUrl: song.artworkUrl,
        durationMs: song.duration.inMilliseconds,
        region: song.region,
        language: song.language,
        genre: song.genre,
        releaseYear: song.releaseYear,
        playCount: song.playCount,
        tags: song.tags,
        isApproved: song.approvalStatus.isApproved,
        isDownloadable: song.isDownloadable,
        lyrics: song.lyrics,
        mood: song.mood,
        albumArtist: song.albumArtist,
        slug: song.slug,
        license: song.license.wire,
        attribution: song.attribution,
        licenseUrl: song.licenseUrl,
        sourceUrl: song.sourceUrl,
        approvalStatus: song.approvalStatus.wire,
        isPublished: song.isPublished,
        rightsCleared: song.rightsCleared,
        submittedBy: song.submittedBy,
      );

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'titleLowercase': title.toLowerCase(),
        'artistId': artistId,
        'artistName': artistName,
        'albumId': albumId,
        'albumTitle': albumTitle,
        'audioUrl': audioUrl,
        'artworkUrl': artworkUrl,
        'durationMs': durationMs,
        'region': region,
        'language': language,
        'genre': genre,
        'releaseYear': releaseYear,
        'playCount': playCount,
        'tags': tags,
        // `isApproved` mirrors approvalStatus so existing queries/indexes keep
        // working without change.
        'isApproved': approvalStatus == 'approved',
        'isDownloadable': isDownloadable,
        'slug': slug,
        'license': license,
        'attribution': attribution,
        'approvalStatus': approvalStatus,
        'isPublished': isPublished,
        'rightsCleared': rightsCleared,
        if (lyrics != null) 'lyrics': lyrics,
        if (mood != null) 'mood': mood,
        if (albumArtist != null) 'albumArtist': albumArtist,
        if (licenseUrl != null) 'licenseUrl': licenseUrl,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        if (submittedBy != null) 'submittedBy': submittedBy,
      };
}
