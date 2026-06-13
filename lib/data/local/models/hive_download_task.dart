import 'package:hive/hive.dart';

part 'hive_download_task.g.dart';

@HiveType(typeId: 1)
class HiveDownloadTask extends HiveObject {
  HiveDownloadTask({
    required this.songId,
    required this.songTitle,
    required this.audioUrl,
    required this.artworkUrl,
    required this.statusIndex,
    this.progress = 0.0,
    this.localPath,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
  });

  @HiveField(0)
  String songId;

  @HiveField(1)
  String songTitle;

  @HiveField(2)
  String audioUrl;

  @HiveField(3)
  String artworkUrl;

  @HiveField(4)
  int statusIndex;

  @HiveField(5)
  double progress;

  @HiveField(6)
  String? localPath;

  @HiveField(7)
  String? errorMessage;

  @HiveField(8)
  DateTime? startedAt;

  @HiveField(9)
  DateTime? completedAt;
}
