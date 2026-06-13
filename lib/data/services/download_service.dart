import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/models/download_task.dart';
import '../../domain/models/song.dart';
import '../local/hive_boxes.dart';
import '../local/models/hive_download_task.dart';
import '../local/models/hive_song.dart';

class DownloadService {
  DownloadService() : _dio = Dio();

  final Dio _dio;
  final Map<String, CancelToken> _cancelTokens = {};

  Stream<DownloadTask> downloadSong(Song song) async* {
    final task = DownloadTask(
      songId: song.id,
      songTitle: song.title,
      audioUrl: song.audioUrl,
      artworkUrl: song.artworkUrl,
      status: DownloadStatus.queued,
      startedAt: DateTime.now(),
    );

    yield task;
    _persistTask(task);

    try {
      final dir = await _getDownloadDirectory();
      final audioFile = File('${dir.path}/${song.id}.mp3');
      final cancelToken = CancelToken();
      _cancelTokens[song.id] = cancelToken;

      DownloadTask? lastEmitted;

      await _dio.download(
        song.audioUrl,
        audioFile.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? received / total : 0.0;
          final updated = task.copyWith(
            status: DownloadStatus.downloading,
            progress: progress,
            fileSizeBytes: total > 0 ? total : null,
            downloadedBytes: received,
          );
          lastEmitted = updated;
          _persistTask(updated);
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          headers: {'Accept': 'audio/mpeg, audio/*'},
        ),
      );

      _cancelTokens.remove(song.id);

      final completed = (lastEmitted ?? task).copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: audioFile.path,
        completedAt: DateTime.now(),
      );

      _persistTask(completed);
      _saveDownloadedSong(song, audioFile.path);

      yield completed;
    } on DioException catch (e) {
      _cancelTokens.remove(song.id);
      final isCancelled = e.type == DioExceptionType.cancel;

      final failed = task.copyWith(
        status: isCancelled ? DownloadStatus.cancelled : DownloadStatus.failed,
        errorMessage: isCancelled ? null : e.message,
      );
      _persistTask(failed);
      yield failed;
    } catch (e) {
      _cancelTokens.remove(song.id);
      final failed = task.copyWith(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
      _persistTask(failed);
      yield failed;
    }
  }

  void cancelDownload(String songId) {
    _cancelTokens[songId]?.cancel('User cancelled');
    _cancelTokens.remove(songId);
  }

  Future<void> deleteDownload(String songId) async {
    final hiveSong = HiveBoxes.downloads.get(songId);
    if (hiveSong != null) {
      final file = File(hiveSong.localAudioPath);
      if (await file.exists()) {
        await file.delete();
      }
      await HiveBoxes.downloads.delete(songId);
    }
    await HiveBoxes.cachedSongs.delete(songId);
  }

  bool isDownloaded(String songId) => HiveBoxes.downloads.containsKey(songId);

  String? getLocalPath(String songId) =>
      HiveBoxes.downloads.get(songId)?.localAudioPath;

  List<Song> getAllDownloadedSongs() {
    return HiveBoxes.downloads.values
        .map((h) => Song(
              id: h.id,
              title: h.title,
              artistId: '',
              artistName: h.artistName,
              albumId: '',
              albumTitle: h.albumTitle,
              audioUrl: '',
              artworkUrl: h.artworkUrl,
              duration: Duration(milliseconds: h.durationMs),
              region: h.region,
              language: h.language,
              genre: h.genre,
              releaseYear: 0,
              playCount: 0,
              tags: const [],
              isApproved: true,
              isDownloadable: true,
              lyrics: h.lyrics,
              localPath: h.localAudioPath,
            ))
        .toList();
  }

  Future<int> getTotalDownloadedSizeBytes() async {
    int total = 0;
    for (final hiveSong in HiveBoxes.downloads.values) {
      final file = File(hiveSong.localAudioPath);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  Future<Directory> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory('${appDir.path}/downloads');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  void _persistTask(DownloadTask task) {
    final hiveTask = HiveDownloadTask(
      songId: task.songId,
      songTitle: task.songTitle,
      audioUrl: task.audioUrl,
      artworkUrl: task.artworkUrl,
      statusIndex: task.status.index,
      progress: task.progress,
      localPath: task.localPath,
      errorMessage: task.errorMessage,
      startedAt: task.startedAt,
      completedAt: task.completedAt,
    );
    HiveBoxes.cachedSongs.put(task.songId, hiveTask);
  }

  void _saveDownloadedSong(Song song, String localPath) {
    final hiveSong = HiveSong(
      id: song.id,
      title: song.title,
      artistName: song.artistName,
      albumTitle: song.albumTitle,
      artworkUrl: song.artworkUrl,
      localAudioPath: localPath,
      durationMs: song.duration.inMilliseconds,
      region: song.region,
      language: song.language,
      genre: song.genre,
      downloadedAt: DateTime.now(),
      lyrics: song.lyrics,
    );
    HiveBoxes.downloads.put(song.id, hiveSong);
  }
}

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});
