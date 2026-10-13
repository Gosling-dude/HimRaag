import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:himraag/core/config/media_config.dart';
import 'package:himraag/data/local/hive_boxes.dart';
import 'package:himraag/data/services/download_service.dart';
import 'package:himraag/data/services/media_url_resolver.dart';
import 'package:himraag/domain/models/download_task.dart';

import 'support/test_songs.dart';

/// Serves canned responses and records every request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory tmp;
  late Directory downloads;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('himraag_dl_test');
    Hive.init(tmp.path);
    await HiveBoxes.registerAdapters();
    await HiveBoxes.openBoxes();
  });

  setUp(() async {
    downloads = await Directory('${tmp.path}/downloads').create();
    await HiveBoxes.downloads.clear();
    await HiveBoxes.cachedSongs.clear();
  });

  tearDown(() => downloads.delete(recursive: true));

  tearDownAll(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  DownloadService service(_FakeAdapter adapter) => DownloadService(
        dio: Dio()..httpClientAdapter = adapter,
        mediaToken: () async => 'tok',
        resolver: const MediaUrlResolver(
          MediaConfig(cdnBase: 'https://cdn.himraag.in'),
        ),
        downloadDirectory: () async => downloads,
      );

  test('downloads via the CDN with a token and saves for offline play',
      () async {
    final bytes = Uint8List.fromList(List.generate(4096, (i) => i % 256));
    final adapter = _FakeAdapter((_) => ResponseBody.fromBytes(bytes, 200,
        headers: {
          Headers.contentLengthHeader: ['${bytes.length}'],
        }));
    final song = testSong();

    final tasks = await service(adapter).downloadSong(song).toList();

    expect(tasks.first.status, DownloadStatus.queued);
    expect(tasks.last.status, DownloadStatus.completed);

    final req = adapter.requests.single.uri;
    expect(req.host, 'cdn.himraag.in');
    expect(req.path, '/audio/bedu-pako.mp3');
    expect(req.queryParameters['t'], 'tok');

    final file = File(tasks.last.localPath!);
    expect(await file.readAsBytes(), bytes);

    final svc = service(adapter);
    expect(svc.isDownloaded(song.id), isTrue);
    final offline = svc.getAllDownloadedSongs().single;
    expect(offline.isDownloaded, isTrue);
    expect(offline.localPath, file.path);
    // The persisted task never stores the token.
    expect(HiveBoxes.cachedSongs.get(song.id)!.audioUrl, song.audioUrl);
  });

  test('a rejected request (e.g. 401 from the CDN) ends as failed', () async {
    final adapter = _FakeAdapter(
        (_) => ResponseBody.fromString('Sign in required', 401));
    final tasks = await service(adapter).downloadSong(testSong()).toList();

    expect(tasks.last.status, DownloadStatus.failed);
    expect(HiveBoxes.downloads.isEmpty, isTrue);
  });

  test('deleteDownload removes the file and the offline record', () async {
    final adapter = _FakeAdapter((_) => ResponseBody.fromBytes(
        Uint8List.fromList([1, 2, 3]), 200));
    final svc = service(adapter);
    final song = testSong();
    final done = await svc.downloadSong(song).last;

    await svc.deleteDownload(song.id);

    expect(File(done.localPath!).existsSync(), isFalse);
    expect(svc.isDownloaded(song.id), isFalse);
  });
}
