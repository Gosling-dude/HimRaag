import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/content_constants.dart';
import '../../../domain/models/album.dart';

class AlbumDto {
  const AlbumDto({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    required this.artworkUrl,
    required this.region,
    required this.language,
    required this.genre,
    required this.releaseYear,
    required this.songCount,
    required this.totalDurationMs,
    this.description,
    this.tags = const [],
    this.isApproved = true,
    this.slug = '',
    this.license = 'DEMO_ONLY',
    this.attribution = '',
    this.approvalStatus = 'pending',
    this.isPublished = false,
    this.rightsCleared = false,
  });

  final String id;
  final String title;
  final String artistId;
  final String artistName;
  final String artworkUrl;
  final String region;
  final String language;
  final String genre;
  final int releaseYear;
  final int songCount;
  final int totalDurationMs;
  final String? description;
  final List<String> tags;
  final bool isApproved;
  final String slug;
  final String license;
  final String attribution;
  final String approvalStatus;
  final bool isPublished;
  final bool rightsCleared;

  factory AlbumDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawStatus = data['approvalStatus'] as String?;
    final approvedFlag = data['isApproved'] as bool? ?? true;
    return AlbumDto(
      id: doc.id,
      title: data['title'] as String? ?? '',
      artistId: data['artistId'] as String? ?? '',
      artistName: data['artistName'] as String? ?? '',
      artworkUrl: data['artworkUrl'] as String? ?? '',
      region: data['region'] as String? ?? '',
      language: data['language'] as String? ?? '',
      genre: data['genre'] as String? ?? '',
      releaseYear: data['releaseYear'] as int? ?? 2024,
      songCount: data['songCount'] as int? ?? 0,
      totalDurationMs: data['totalDurationMs'] as int? ?? 0,
      description: data['description'] as String?,
      tags: List<String>.from(data['tags'] as List? ?? []),
      isApproved: approvedFlag,
      slug: data['slug'] as String? ?? '',
      license: data['license'] as String? ?? 'DEMO_ONLY',
      attribution: data['attribution'] as String? ?? '',
      approvalStatus: rawStatus ?? (approvedFlag ? 'approved' : 'pending'),
      isPublished: data['isPublished'] as bool? ?? false,
      rightsCleared: data['rightsCleared'] as bool? ?? false,
    );
  }

  Album toDomain() => Album(
        id: id,
        title: title,
        artistId: artistId,
        artistName: artistName,
        artworkUrl: artworkUrl,
        region: region,
        language: language,
        genre: genre,
        releaseYear: releaseYear,
        songCount: songCount,
        totalDuration: Duration(milliseconds: totalDurationMs),
        description: description,
        tags: tags,
        isApproved: isApproved,
        slug: slug,
        license: LicenseType.fromWire(license),
        attribution: attribution,
        approvalStatus: ApprovalStatus.fromWire(approvalStatus),
        isPublished: isPublished,
        rightsCleared: rightsCleared,
      );

  factory AlbumDto.fromDomain(Album album) => AlbumDto(
        id: album.id,
        title: album.title,
        artistId: album.artistId,
        artistName: album.artistName,
        artworkUrl: album.artworkUrl,
        region: album.region,
        language: album.language,
        genre: album.genre,
        releaseYear: album.releaseYear,
        songCount: album.songCount,
        totalDurationMs: album.totalDuration.inMilliseconds,
        description: album.description,
        tags: album.tags,
        isApproved: album.approvalStatus.isApproved,
        slug: album.slug,
        license: album.license.wire,
        attribution: album.attribution,
        approvalStatus: album.approvalStatus.wire,
        isPublished: album.isPublished,
        rightsCleared: album.rightsCleared,
      );

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'titleLowercase': title.toLowerCase(),
        'artistId': artistId,
        'artistName': artistName,
        'artworkUrl': artworkUrl,
        'region': region,
        'language': language,
        'genre': genre,
        'releaseYear': releaseYear,
        'songCount': songCount,
        'totalDurationMs': totalDurationMs,
        'tags': tags,
        'isApproved': approvalStatus == 'approved',
        'slug': slug,
        'license': license,
        'attribution': attribution,
        'approvalStatus': approvalStatus,
        'isPublished': isPublished,
        'rightsCleared': rightsCleared,
        if (description != null) 'description': description,
      };
}
