import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory AlbumDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      isApproved: data['isApproved'] as bool? ?? true,
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
      );
}
