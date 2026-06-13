import 'package:cloud_firestore/cloud_firestore.dart';

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
      );
}
