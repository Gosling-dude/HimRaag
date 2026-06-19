import 'package:flutter_test/flutter_test.dart';

import 'package:himraag/data/local/local_catalog_datasource.dart';

/// Proves the imported songs reach the app at runtime: the bundled asset
/// `assets/catalog/imported_catalog.json` is loaded by LocalCatalogDatasource
/// (the same path the providers use) and the named songs are returned and
/// searchable. This is the runtime layer that was missing — without it the
/// app only sees the Firestore demo catalog.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ds = LocalCatalogDatasource();

  test('bundled catalog loads the imported songs at runtime', () async {
    final songs = await ds.songs();
    expect(songs, isNotEmpty);
    // Original 19 imported songs + 68 newly imported Pahadi songs = 87.
    expect(songs.length, 87);
    final titles = songs.map((s) => s.title).toList();
    // Original batch still present (merge is additive).
    expect(titles.any((t) => t.contains('AANKHI MICHOLI')), isTrue);
    expect(titles.any((t) => t.contains('Main Pahadan')), isTrue);
    expect(titles.any((t) => t.contains('Baadri')), isTrue);
    // New batch present.
    expect(titles.any((t) => t.contains('Baleno')), isTrue);
    expect(titles.any((t) => t.contains('Dhol Damau')), isTrue);
  });

  test('imported songs are searchable by name', () async {
    final r = await ds.search('aankhi');
    expect(r.songs.map((s) => s.title), contains(contains('AANKHI MICHOLI')));

    final r2 = await ds.search('baadri');
    expect(r2.songs, isNotEmpty);

    final r3 = await ds.search('main pahadan');
    expect(r3.songs, isNotEmpty);
  });

  test('imported songs are LICENSED + approved (pass visibility filter)',
      () async {
    final songs = await ds.songs();
    for (final s in songs) {
      expect(s.isApproved, isTrue, reason: s.title);
      expect(s.license.cleared, isTrue, reason: s.title);
      // Audio now streams from Cloudflare R2 (bundled MP3s removed).
      expect(s.audioUrl, startsWith('https://'), reason: s.title);
      expect(s.audioUrl, contains('r2.dev/audio/'), reason: s.title);
      // Catalog has been polished for release: review flags are cleared so the
      // consumer UI shows clean, professional metadata (no "Needs Review").
      expect(s.reviewRequired, isFalse, reason: s.title);
    }
  });

  test('catalog carries no consumer-facing review/Unknown sentinels', () async {
    final songs = await ds.songs();
    final artists = await ds.artists();
    final albums = await ds.albums();
    for (final s in songs) {
      expect(s.artistName, isNot('Unknown Artist'), reason: s.title);
      expect(s.region, isNot('Needs Review'), reason: s.title);
    }
    for (final a in artists) {
      expect(a.name, isNot('Unknown Artist'), reason: a.id);
      expect(a.region, isNot('Needs Review'), reason: a.id);
    }
    for (final a in albums) {
      expect(a.title, isNot('Imported Recordings'), reason: a.id);
    }
  });

  test('local album + artist resolve for detail pages', () async {
    final albums = await ds.albums();
    final artists = await ds.artists();
    expect(albums, isNotEmpty);
    expect(artists, isNotEmpty);
    final album = await ds.albumById(albums.first.id);
    expect(album, isNotNull);
    final songsInAlbum = await ds.songsForAlbum(albums.first.id);
    expect(songsInAlbum, isNotEmpty);
    final songsByArtist = await ds.songsForArtist(artists.first.id);
    expect(songsByArtist, isNotEmpty);
  });
}
