import 'package:cloud_firestore/cloud_firestore.dart';

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

  factory SongDto.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
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
      isApproved: data['isApproved'] as bool? ?? false,
      isDownloadable: data['isDownloadable'] as bool? ?? true,
      lyrics: data['lyrics'] as String?,
      mood: data['mood'] as String?,
      albumArtist: data['albumArtist'] as String?,
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
      );

  Map<String, dynamic> toFirestore() => {
        'title': title,
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
        'isApproved': isApproved,
        'isDownloadable': isDownloadable,
        if (lyrics != null) 'lyrics': lyrics,
        if (mood != null) 'mood': mood,
        if (albumArtist != null) 'albumArtist': albumArtist,
      };
}
