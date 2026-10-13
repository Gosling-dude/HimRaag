import 'package:flutter_test/flutter_test.dart';
import 'package:himraag/domain/models/song.dart';
import 'package:himraag/features/recommendations/recommender.dart';

Song _song(String id, String artist, String region,
        {String genre = 'Folk', int plays = 0}) =>
    Song(
      id: id,
      title: id,
      artistId: artist,
      artistName: artist,
      albumId: '',
      albumTitle: '',
      audioUrl: 'https://x/$id.mp3',
      artworkUrl: '',
      duration: const Duration(minutes: 4),
      region: region,
      language: region,
      genre: genre,
      releaseYear: 2026,
      playCount: plays,
      tags: const [],
      isApproved: true,
      isDownloadable: true,
    );

void main() {
  const r = Recommender();

  test('same artist beats same region beats unrelated', () {
    final profile =
        TasteProfile.fromSeeds([(_song('seed', 'attar', 'Jaunsari'), 1)]);
    final ranked = r.rank([
      _song('other', 'kedar', 'Kinnauri', genre: 'Devotional'),
      _song('region', 'meena', 'Jaunsari'),
      _song('artist', 'attar', 'Jaunsari'),
    ], profile);
    expect(ranked.map((s) => s.id), ['artist', 'region', 'other']);
  });

  test('excluded songs never come back', () {
    final profile =
        TasteProfile.fromSeeds([(_song('seed', 'attar', 'Jaunsari'), 1)]);
    final ranked = r.rank(
        [_song('a', 'attar', 'Jaunsari'), _song('b', 'attar', 'Jaunsari')],
        profile,
        exclude: {'a'});
    expect(ranked.map((s) => s.id), ['b']);
  });

  test('caps songs per artist, then fills from the overflow', () {
    final profile =
        TasteProfile.fromSeeds([(_song('seed', 'attar', 'Jaunsari'), 1)]);
    final candidates = [
      for (var i = 0; i < 4; i++) _song('attar$i', 'attar', 'Jaunsari'),
      _song('meena', 'meena', 'Jaunsari'),
    ];
    final top3 = r.rank(candidates, profile, limit: 3, perArtist: 2);
    expect(top3.where((s) => s.artistId == 'attar'), hasLength(2));
    expect(top3.map((s) => s.id), contains('meena'));
    expect(r.rank(candidates, profile, limit: 5, perArtist: 2), hasLength(5));
  });

  test('heavier seeds pull harder', () {
    final profile = TasteProfile.fromSeeds([
      (_song('fav', 'negi', 'Garhwali'), 3),
      (_song('once', 'attar', 'Jaunsari'), 0.3),
    ]);
    final ranked = r.rank(
        [_song('j', 'attar', 'Jaunsari'), _song('g', 'negi', 'Garhwali')],
        profile);
    expect(ranked.first.id, 'g');
  });

  test('similarTo leaves out the seed itself', () {
    final seed = _song('seed', 'attar', 'Jaunsari');
    final similar = r.similarTo(seed, [seed, _song('x', 'attar', 'Jaunsari')]);
    expect(similar.map((s) => s.id), ['x']);
  });

  test('duplicate candidates are ranked once', () {
    final profile =
        TasteProfile.fromSeeds([(_song('seed', 'attar', 'Jaunsari'), 1)]);
    final s = _song('dup', 'attar', 'Jaunsari');
    expect(r.rank([s, s, s], profile), hasLength(1));
  });
}
