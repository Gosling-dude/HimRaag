import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';

/// On-device playback verification for the locally-imported audio.
///
/// Requires a connected device or emulator (just_audio needs the platform
/// audio engine):
///
///   flutter test integration_test/playback_test.dart
///
/// For each bundled asset it asserts:
///   • the source loads and reports a real, non-zero duration (not 00:00)
///   • play() starts playback (position advances)
///   • pause() stops it
///   • seek() moves the position
/// …and over a multi-track playlist that next / previous switch tracks.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> songs;

  setUpAll(() async {
    // The catalog is bundled implicitly via the asset files; read the JSON the
    // generator produced (kept under scripts/seed_data) through the asset
    // bundle is not possible, so we hard-read the asset audio keys here.
    final raw = await rootBundle.loadString('AssetManifest.json');
    final manifest = jsonDecode(raw) as Map<String, dynamic>;
    final audioKeys = manifest.keys
        .where((k) => k.startsWith('assets/audio/') && k.endsWith('.mp3'))
        .toList()
      ..sort();
    songs = audioKeys
        .map((k) => {'title': k.split('/').last, 'asset': k})
        .toList();
    expect(songs, isNotEmpty, reason: 'no bundled audio assets found');
  });

  testWidgets('each imported track loads a real duration', (tester) async {
    for (final s in songs) {
      final player = AudioPlayer();
      try {
        final duration = await player
            .setAudioSource(AudioSource.asset(s['asset'] as String))
            .timeout(const Duration(seconds: 20));
        expect(duration, isNotNull, reason: '${s['title']} returned no duration');
        expect(duration! > Duration.zero, isTrue,
            reason: '${s['title']} loaded 00:00');
      } finally {
        await player.dispose();
      }
    }
  });

  testWidgets('play / pause / seek work on the first track', (tester) async {
    final player = AudioPlayer();
    try {
      await player.setAudioSource(AudioSource.asset(songs.first['asset'] as String));
      await player.play();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(player.playing, isTrue);
      expect(player.position, greaterThan(Duration.zero));

      await player.pause();
      expect(player.playing, isFalse);

      await player.seek(const Duration(seconds: 30));
      expect(player.position, greaterThanOrEqualTo(const Duration(seconds: 29)));
    } finally {
      await player.dispose();
    }
  });

  testWidgets('next / previous switch tracks in a playlist', (tester) async {
    final player = AudioPlayer();
    try {
      final playlist = ConcatenatingAudioSource(
        children: songs
            .take(3)
            .map((s) => AudioSource.asset(s['asset'] as String))
            .toList(),
      );
      await player.setAudioSource(playlist);
      expect(player.currentIndex, 0);

      await player.seekToNext();
      expect(player.currentIndex, 1);

      await player.seekToNext();
      expect(player.currentIndex, 2);

      await player.seekToPrevious();
      expect(player.currentIndex, 1);
    } finally {
      await player.dispose();
    }
  });
}
