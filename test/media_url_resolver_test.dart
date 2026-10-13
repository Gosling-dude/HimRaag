import 'package:flutter_test/flutter_test.dart';

import 'package:himraag/core/config/media_config.dart';
import 'package:himraag/data/services/audio_player_service.dart';
import 'package:himraag/data/services/media_url_resolver.dart';

import 'support/test_songs.dart';

void main() {
  const cdn = MediaUrlResolver(MediaConfig(cdnBase: 'https://cdn.himraag.in'));
  const off = MediaUrlResolver(MediaConfig(cdnBase: ''));

  group('resolve', () {
    test('moves r2.dev URLs onto the CDN, keeping the path', () {
      expect(
        cdn.resolve('https://pub-abc.r2.dev/audio/main%20pahadan.mp3'),
        'https://cdn.himraag.in/audio/main%20pahadan.mp3',
      );
    });

    test('leaves other hosts, empty and local values alone', () {
      for (final url in [
        'https://picsum.photos/seed/1/300',
        'https://cdn.himraag.in/artwork/a.png',
        '',
        'asset:///assets/audio/a.mp3',
        '/data/user/0/downloads/a.mp3',
      ]) {
        expect(cdn.resolve(url), url, reason: url);
      }
    });

    test('is a no-op when no CDN is configured', () {
      const url = 'https://pub-abc.r2.dev/audio/a.mp3';
      expect(off.resolve(url), url);
    });
  });

  group('authorize', () {
    test('adds the token to protected audio on the CDN', () {
      final uri = cdn.authorize('https://pub-abc.r2.dev/audio/a.mp3', 'tok');
      expect(uri.host, 'cdn.himraag.in');
      expect(uri.queryParameters['t'], 'tok');
    });

    test('never sends the token to artwork or foreign hosts', () {
      expect(
        cdn.authorize('https://pub-abc.r2.dev/artwork/a.png', 'tok').query,
        isEmpty,
      );
      expect(cdn.authorize('https://example.com/audio/a.mp3', 'tok').query,
          isEmpty);
      expect(off.authorize('https://pub-abc.r2.dev/audio/a.mp3', 'tok').query,
          isEmpty);
    });

    test('still returns a playable URL without a token', () {
      final uri = cdn.authorize('https://pub-abc.r2.dev/audio/a.mp3', null);
      expect(uri.toString(), 'https://cdn.himraag.in/audio/a.mp3');
    });
  });

  group('playbackUriFor', () {
    test('plays downloaded songs from disk, never the network', () {
      final song = testSong(localPath: '/tmp/downloads/bedu-pako.mp3');
      final uri = playbackUriFor(song, 'tok', cdn);
      expect(uri.scheme, 'file');
      expect(uri.toFilePath(), '/tmp/downloads/bedu-pako.mp3');
    });

    test('streams other songs from the CDN with the token', () {
      final uri = playbackUriFor(testSong(), 'tok', cdn);
      expect(uri.toString(),
          'https://cdn.himraag.in/audio/bedu-pako.mp3?t=tok');
    });
  });
}
