import 'package:hive/hive.dart';

part 'hive_recently_played.g.dart';

@HiveType(typeId: 2)
class HiveRecentlyPlayed extends HiveObject {
  HiveRecentlyPlayed({
    required this.songId,
    required this.songTitle,
    required this.artistName,
    required this.artworkUrl,
    required this.playedAt,
    this.audioUrl,
    this.localPath,
  });

  @HiveField(0)
  String songId;

  @HiveField(1)
  String songTitle;

  @HiveField(2)
  String artistName;

  @HiveField(3)
  String artworkUrl;

  @HiveField(4)
  DateTime playedAt;

  @HiveField(5)
  String? audioUrl;

  @HiveField(6)
  String? localPath;
}
