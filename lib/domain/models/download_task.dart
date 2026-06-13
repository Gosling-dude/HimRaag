import 'package:equatable/equatable.dart';

enum DownloadStatus { queued, downloading, completed, failed, cancelled }

class DownloadTask extends Equatable {
  const DownloadTask({
    required this.songId,
    required this.songTitle,
    required this.audioUrl,
    required this.artworkUrl,
    required this.status,
    this.progress = 0.0,
    this.localPath,
    this.errorMessage,
    this.startedAt,
    this.completedAt,
    this.fileSizeBytes,
    this.downloadedBytes,
  });

  final String songId;
  final String songTitle;
  final String audioUrl;
  final String artworkUrl;
  final DownloadStatus status;
  final double progress;
  final String? localPath;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? fileSizeBytes;
  final int? downloadedBytes;

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  DownloadTask copyWith({
    String? songId,
    String? songTitle,
    String? audioUrl,
    String? artworkUrl,
    DownloadStatus? status,
    double? progress,
    String? localPath,
    String? errorMessage,
    DateTime? startedAt,
    DateTime? completedAt,
    int? fileSizeBytes,
    int? downloadedBytes,
  }) {
    return DownloadTask(
      songId: songId ?? this.songId,
      songTitle: songTitle ?? this.songTitle,
      audioUrl: audioUrl ?? this.audioUrl,
      artworkUrl: artworkUrl ?? this.artworkUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    );
  }

  @override
  List<Object?> get props => [
        songId,
        songTitle,
        audioUrl,
        artworkUrl,
        status,
        progress,
        localPath,
        errorMessage,
        startedAt,
        completedAt,
        fileSizeBytes,
        downloadedBytes,
      ];
}
