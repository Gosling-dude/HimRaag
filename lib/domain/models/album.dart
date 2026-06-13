import 'package:equatable/equatable.dart';

class Album extends Equatable {
  const Album({
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
    required this.totalDuration,
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
  final Duration totalDuration;
  final String? description;
  final List<String> tags;
  final bool isApproved;

  Album copyWith({
    String? id,
    String? title,
    String? artistId,
    String? artistName,
    String? artworkUrl,
    String? region,
    String? language,
    String? genre,
    int? releaseYear,
    int? songCount,
    Duration? totalDuration,
    String? description,
    List<String>? tags,
    bool? isApproved,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      region: region ?? this.region,
      language: language ?? this.language,
      genre: genre ?? this.genre,
      releaseYear: releaseYear ?? this.releaseYear,
      songCount: songCount ?? this.songCount,
      totalDuration: totalDuration ?? this.totalDuration,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        artistId,
        artistName,
        artworkUrl,
        region,
        language,
        genre,
        releaseYear,
        songCount,
        totalDuration,
        description,
        tags,
        isApproved,
      ];
}
