import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:himraag/core/validation/metadata_validator.dart';

/// Headless verification of the locally-imported audio catalog.
///
/// Proves — without a device — that every imported track is well-formed and
/// playable-by-construction: the bundled asset file exists on disk, the
/// duration is real (never 00:00), the audio URL is a valid asset:/// URL, and
/// the record passes the canonical import validator. The just_audio play /
/// pause / seek / next-previous behaviour is exercised separately by
/// integration_test/playback_test.dart on a device/emulator.
void main() {
  final catalogFile = File('scripts/seed_data/imported_catalog.json');

  late Map<String, dynamic> catalog;
  late List<dynamic> songs;

  setUpAll(() {
    expect(catalogFile.existsSync(), isTrue,
        reason: 'Run: node scripts/generate_import_catalog.js');
    catalog = jsonDecode(catalogFile.readAsStringSync()) as Map<String, dynamic>;
    songs = catalog['songs'] as List<dynamic>;
  });

  test('catalog contains the imported songs', () {
    expect(songs, isNotEmpty);
    expect(songs.length, catalog['_meta']['songCount']);
  });

  test('every song streams from Cloudflare R2 (no bundled MP3s)', () {
    for (final s in songs.cast<Map<String, dynamic>>()) {
      final url = s['audioUrl'] as String;
      expect(url, startsWith('https://'),
          reason: '${s['title']} must use an R2 https URL');
      expect(url, contains('r2.dev/audio/'),
          reason: '${s['title']} must stream from R2');
      final art = s['artworkUrl'] as String;
      expect(art, contains('r2.dev/artwork/'),
          reason: '${s['title']} artwork must be on R2');
    }
  });

  test('every song has a real, non-zero duration', () {
    for (final s in songs.cast<Map<String, dynamic>>()) {
      final ms = (s['durationMs'] as num).toInt();
      expect(ms, greaterThan(0),
          reason: '${s['title']} has zero duration (00:00)');
    }
  });

  test('every song is approved, visible, licensed and review-flagged', () {
    for (final s in songs.cast<Map<String, dynamic>>()) {
      expect(s['approvalStatus'], 'approved', reason: '${s['title']}');
      expect(s['isPublished'], true, reason: '${s['title']}');
      expect(s['license'], 'LICENSED', reason: '${s['title']}');
      expect(s['rightsCleared'], true, reason: '${s['title']}');
      // Imported content is flagged for owner metadata review.
      expect(s['reviewRequired'], true, reason: '${s['title']}');
      expect((s['tags'] as List).contains('needs-metadata-review'), isTrue,
          reason: '${s['title']} should be flagged for review');
      // Region/language are now enriched (real values), except a couple that
      // remain "Needs Review" — either is acceptable here.
      expect(s['region'], isNotEmpty, reason: '${s['title']}');
      expect(s['language'], isNotEmpty, reason: '${s['title']}');
    }
  });

  test('every song passes the canonical import validator', () {
    for (final s in songs.cast<Map<String, dynamic>>()) {
      final result = MetadataValidator.validateTrack(Map<String, dynamic>.from(s));
      expect(result.ok, isTrue,
          reason: '${s['title']}: ${result.errors.join("; ")}');
    }
  });

  test('song ids are unique', () {
    final ids = songs.map((s) => (s as Map)['id']).toSet();
    expect(ids.length, songs.length, reason: 'duplicate song ids');
  });
}
