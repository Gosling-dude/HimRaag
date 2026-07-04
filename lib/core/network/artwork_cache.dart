import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;

/// Artwork/image cache tuned for the public R2 host.
///
/// The `pub-*.r2.dev` public bucket URL is rate-limited by Cloudflare (bursts
/// of image requests start returning HTTP 429, which is exactly what a Home
/// screen full of covers produces). Three defenses, in order:
///
///   1. **Bounded concurrency** — at most [_maxConcurrent] simultaneous image
///      downloads; the rest queue. Keeps first-launch bursts under the limit.
///   2. **Aggressive disk cache** — 30-day stale period, so an image is
///      fetched from the network once and then served from disk. Warm
///      launches and scrolling do not hit the network at all.
///   3. **Request timeout** — a hung response can never leave a placeholder
///      shimmering forever; it fails fast and the widget-level retry/backoff
///      (see AppArtwork) takes over.
class ArtworkCacheManager {
  static const key = 'himraagArtwork';

  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 3000,
      fileService: _ThrottledHttpFileService(),
    ),
  );
}

class _ThrottledHttpFileService extends FileService {
  _ThrottledHttpFileService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const int _maxConcurrent = 4;
  static const Duration _timeout = Duration(seconds: 20);

  int _active = 0;
  final _waiters = <Completer<void>>[];

  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _waiters.add(c);
    await c.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else {
      _active--;
    }
  }

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    await _acquire();
    var released = false;
    void releaseOnce() {
      if (!released) {
        released = true;
        _release();
      }
    }

    try {
      final req = http.Request('GET', Uri.parse(url));
      if (headers != null) req.headers.addAll(headers);
      final res = await _client.send(req).timeout(_timeout);
      // Non-2xx (429 while throttled, 404 stale, …) must be an *error*, never
      // cached: throwing routes the widget to its retry/backoff path.
      if (res.statusCode < 200 || res.statusCode >= 300) {
        // Drain to free the connection before failing.
        unawaited(res.stream.drain<void>().catchError((_) {}));
        throw HttpExceptionWithStatus(
          res.statusCode,
          'Image fetch failed ($url)',
          uri: Uri.parse(url),
        );
      }
      // Hold the slot until the body finishes streaming (that is the real
      // network work) — release on done/error, with a hard timeout backstop.
      final controller = StreamController<List<int>>();
      final timer = Timer(_timeout * 2, releaseOnce);
      res.stream.listen(
        controller.add,
        onError: (Object e, StackTrace st) {
          controller.addError(e, st);
          timer.cancel();
          releaseOnce();
          controller.close();
        },
        onDone: () {
          timer.cancel();
          releaseOnce();
          controller.close();
        },
        cancelOnError: true,
      );
      final wrapped = http.StreamedResponse(
        controller.stream,
        res.statusCode,
        contentLength: res.contentLength,
        request: res.request,
        headers: res.headers,
        reasonPhrase: res.reasonPhrase,
      );
      return HttpGetResponse(wrapped);
    } catch (_) {
      releaseOnce();
      rethrow;
    }
  }
}
