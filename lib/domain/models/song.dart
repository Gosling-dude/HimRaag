import 'package:equatable/equatable.dart';

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
      ];
}
