import 'package:equatable/equatable.dart';

import '../../core/constants/content_constants.dart';

class Artist extends Equatable {
  const Artist({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.region,
    required this.bio,
    required this.songCount,
    required this.albumCount,
    required this.genres,
    this.monthlyListeners = 0,
    this.isVerified = false,
    this.socialLinks = const {},
    this.slug = '',
    this.ownerUid,
    this.approvalStatus = ApprovalStatus.pending,
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

  // ── Content-system metadata ──────────────────────────────────────────────
  final String slug;

  /// UID of the user account that manages this artist profile (artist
  /// dashboard ownership). Null for catalog/demo artists with no account.
  final String? ownerUid;
  final ApprovalStatus approvalStatus;
  final bool isPublished;

  /// Free-text rights/permission note captured from the artist, stored exactly.
  final String rightsNote;

  Artist copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? region,
    String? bio,
    int? songCount,
    int? albumCount,
    List<String>? genres,
    int? monthlyListeners,
    bool? isVerified,
    Map<String, String>? socialLinks,
    String? slug,
    String? ownerUid,
    ApprovalStatus? approvalStatus,
    bool? isPublished,
    String? rightsNote,
  }) {
    return Artist(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      region: region ?? this.region,
      bio: bio ?? this.bio,
      songCount: songCount ?? this.songCount,
      albumCount: albumCount ?? this.albumCount,
      genres: genres ?? this.genres,
      monthlyListeners: monthlyListeners ?? this.monthlyListeners,
      isVerified: isVerified ?? this.isVerified,
      socialLinks: socialLinks ?? this.socialLinks,
      slug: slug ?? this.slug,
      ownerUid: ownerUid ?? this.ownerUid,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      isPublished: isPublished ?? this.isPublished,
      rightsNote: rightsNote ?? this.rightsNote,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        imageUrl,
        region,
        bio,
        songCount,
        albumCount,
        genres,
        monthlyListeners,
        isVerified,
        socialLinks,
        slug,
        ownerUid,
        approvalStatus,
        isPublished,
        rightsNote,
      ];
}
