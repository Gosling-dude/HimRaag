import 'package:equatable/equatable.dart';

class Playlist extends Equatable {
  const Playlist({
    required this.id,
    required this.title,
    required this.songIds,
    required this.createdAt,
    this.description,
    this.artworkUrl,
    this.isUserCreated = true,
    this.isPublic = false,
    this.ownerId,
    this.updatedAt,
  });

  final String id;
  final String title;
  final List<String> songIds;
  final DateTime createdAt;
  final String? description;
  final String? artworkUrl;
  final bool isUserCreated;
  final bool isPublic;
  final String? ownerId;
  final DateTime? updatedAt;

  int get songCount => songIds.length;

  Playlist copyWith({
    String? id,
    String? title,
    List<String>? songIds,
    DateTime? createdAt,
    String? description,
    String? artworkUrl,
    bool? isUserCreated,
    bool? isPublic,
    String? ownerId,
    DateTime? updatedAt,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      isUserCreated: isUserCreated ?? this.isUserCreated,
      isPublic: isPublic ?? this.isPublic,
      ownerId: ownerId ?? this.ownerId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        songIds,
        createdAt,
        description,
        artworkUrl,
        isUserCreated,
        isPublic,
        ownerId,
        updatedAt,
      ];
}
