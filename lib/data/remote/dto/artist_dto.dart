import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/content_constants.dart';
import '../../../domain/models/artist.dart';

class ArtistDto {
  const ArtistDto({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.region,
    required this.bio,
    required this.songCount,
    required this.albumCount,
    required this.genres,
    required this.monthlyListeners,
    required this.isVerified,
    required this.socialLinks,
    this.slug = '',
    this.ownerUid,
    this.approvalStatus = 'pending',
    this.isPublished = false,
    this.rightsNote = '',
  });

  final String id;
  final String name;
  final String imageUrl;
  final String region;
  final String bio;
  final int songCount;
  final int albumCount;
  final List<String> genres;
  final int monthlyListeners;
  final bool isVerified;
  final Map<String, String> socialLinks;
  final String slug;
  final String? ownerUid;
  final String approvalStatus;
  final bool isPublished;
  final String rightsNote;

  factory ArtistDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ArtistDto(
      id: doc.id,
      name: data['name'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      region: data['region'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      songCount: data['songCount'] as int? ?? 0,
      albumCount: data['albumCount'] as int? ?? 0,
      genres: List<String>.from(data['genres'] as List? ?? []),
      monthlyListeners: data['monthlyListeners'] as int? ?? 0,
      isVerified: data['isVerified'] as bool? ?? false,
      socialLinks: Map<String, String>.from(data['socialLinks'] as Map? ?? {}),
      slug: data['slug'] as String? ?? '',
      ownerUid: data['ownerUid'] as String?,
      approvalStatus: data['approvalStatus'] as String? ?? 'pending',
      isPublished: data['isPublished'] as bool? ?? false,
      rightsNote: data['rightsNote'] as String? ?? '',
    );
  }

  Artist toDomain() => Artist(
        id: id,
        name: name,
        imageUrl: imageUrl,
        region: region,
        bio: bio,
        songCount: songCount,
        albumCount: albumCount,
        genres: genres,
        monthlyListeners: monthlyListeners,
        isVerified: isVerified,
        socialLinks: socialLinks,
        slug: slug,
        ownerUid: ownerUid,
        approvalStatus: ApprovalStatus.fromWire(approvalStatus),
        isPublished: isPublished,
        rightsNote: rightsNote,
      );

  factory ArtistDto.fromDomain(Artist artist) => ArtistDto(
        id: artist.id,
        name: artist.name,
        imageUrl: artist.imageUrl,
        region: artist.region,
        bio: artist.bio,
        songCount: artist.songCount,
        albumCount: artist.albumCount,
        genres: artist.genres,
        monthlyListeners: artist.monthlyListeners,
        isVerified: artist.isVerified,
        socialLinks: artist.socialLinks,
        slug: artist.slug,
        ownerUid: artist.ownerUid,
        approvalStatus: artist.approvalStatus.wire,
        isPublished: artist.isPublished,
        rightsNote: artist.rightsNote,
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'nameLowercase': name.toLowerCase(),
        'imageUrl': imageUrl,
        'region': region,
        'bio': bio,
        'songCount': songCount,
        'albumCount': albumCount,
        'genres': genres,
        'monthlyListeners': monthlyListeners,
        'isVerified': isVerified,
        'socialLinks': socialLinks,
        'slug': slug,
        'approvalStatus': approvalStatus,
        'isPublished': isPublished,
        'rightsNote': rightsNote,
        if (ownerUid != null) 'ownerUid': ownerUid,
      };
}
