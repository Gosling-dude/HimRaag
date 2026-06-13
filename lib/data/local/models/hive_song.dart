import 'package:hive/hive.dart';

part 'hive_song.g.dart';

@HiveType(typeId: 0)
class HiveSong extends HiveObject {
  HiveSong({
    required this.id,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.artworkUrl,
    required this.localAudioPath,
    required this.durationMs,
    required this.region,
    required this.language,
    required this.genre,
    required this.downloadedAt,
    this.lyrics,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String artistName;

  @HiveField(3)
  String albumTitle;

  @HiveField(4)
  String artworkUrl;

  @HiveField(5)
  String localAudioPath;

  @HiveField(6)
  int durationMs;

  @HiveField(7)
  String region;

  @HiveField(8)
  String language;

  @HiveField(9)
  String genre;

  @HiveField(10)
  DateTime downloadedAt;

  @HiveField(11)
  String? lyrics;
}
