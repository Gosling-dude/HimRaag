import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/download_service.dart';
import '../../../domain/models/download_task.dart';
import '../../../domain/models/song.dart';

final activeDownloadsProvider =
    StateNotifierProvider<ActiveDownloadsNotifier, Map<String, DownloadTask>>(
        (ref) {
  return ActiveDownloadsNotifier(ref.watch(downloadServiceProvider));
});

class ActiveDownloadsNotifier extends StateNotifier<Map<String, DownloadTask>> {
  ActiveDownloadsNotifier(this._downloadService) : super({});

  final DownloadService _downloadService;

  Future<void> startDownload(Song song) async {
    if (state.containsKey(song.id) &&
        state[song.id]!.status == DownloadStatus.downloading) {
      return;
    }
    if (_downloadService.isDownloaded(song.id)) return;

    _downloadService.downloadSong(song).listen(
      (task) {
        state = {...state, song.id: task};
        if (task.status == DownloadStatus.completed ||
            task.status == DownloadStatus.failed ||
            task.status == DownloadStatus.cancelled) {
          Future.delayed(const Duration(seconds: 2), () {
            state = Map.from(state)..remove(song.id);
          });
        }
      },
    );
  }

  void cancelDownload(String songId) {
    _downloadService.cancelDownload(songId);
    state = Map.from(state)..remove(songId);
  }
}

final isDownloadedProvider = Provider.family<bool, String>((ref, songId) {
  return ref.watch(downloadServiceProvider).isDownloaded(songId);
});

final downloadProgressProvider =
    Provider.family<DownloadTask?, String>((ref, songId) {
  return ref.watch(activeDownloadsProvider)[songId];
});
