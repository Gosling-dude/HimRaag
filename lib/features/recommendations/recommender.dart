import 'dart:math' as math;

import '../../domain/models/song.dart';

/// What a listener leans towards, built from songs they played, liked or
/// downloaded. Each signal is a weight per artist / region / genre / mood /
/// tag; more recent and more deliberate signals (a favorite) weigh more.
class TasteProfile {
  TasteProfile._(
      this.artists, this.regions, this.genres, this.moods, this.tags);

  /// [weighted] pairs each seed song with how strongly it counts.
  factory TasteProfile.fromSeeds(Iterable<(Song, double)> weighted) {
    final artists = <String, double>{};
    final regions = <String, double>{};
    final genres = <String, double>{};
    final moods = <String, double>{};
    final tags = <String, double>{};
    void bump(Map<String, double> m, String? key, double w) {
      final k = key?.trim().toLowerCase() ?? '';
      if (k.isNotEmpty) m[k] = (m[k] ?? 0) + w;
    }

    for (final (song, w) in weighted) {
      bump(artists, song.artistId, w);
      bump(regions, song.region, w);
      bump(genres, song.genre, w);
      bump(moods, song.mood, w);
      for (final t in song.tags) {
        bump(tags, t, w);
      }
    }
    return TasteProfile._(artists, regions, genres, moods, tags);
  }

  final Map<String, double> artists;
  final Map<String, double> regions;
  final Map<String, double> genres;
  final Map<String, double> moods;
  final Map<String, double> tags;

  bool get isEmpty => artists.isEmpty && regions.isEmpty && genres.isEmpty;

  /// Keys of [m] by descending weight.
  static List<String> top(Map<String, double> m, int n) =>
      (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(n)
          .map((e) => e.key)
          .toList();
}

/// Content-based recommender: scores candidates by overlap with a
/// [TasteProfile] (artist > region > genre > mood > tags), with a light
/// popularity nudge, then spreads artists out so one singer can't fill a row.
class Recommender {
  const Recommender();

  static const double artistWeight = 3;
  static const double regionWeight = 1.5;
  static const double genreWeight = 1;
  static const double moodWeight = 0.6;
  static const double tagWeight = 0.3;

  double score(Song s, TasteProfile p) {
    double share(Map<String, double> m, String? key) {
      if (m.isEmpty || key == null || key.isEmpty) return 0;
      final total = m.values.fold<double>(0, (a, b) => a + b);
      return (m[key.toLowerCase()] ?? 0) / total;
    }

    final tagShare = s.tags.fold<double>(0, (a, t) => a + share(p.tags, t));
    return artistWeight * share(p.artists, s.artistId) +
        regionWeight * share(p.regions, s.region) +
        genreWeight * share(p.genres, s.genre) +
        moodWeight * share(p.moods, s.mood) +
        tagWeight * math.min(tagShare, 1) +
        0.05 * math.log(1 + s.playCount);
  }

  /// Best [limit] of [candidates] for [profile], skipping [exclude] ids and
  /// allowing at most [perArtist] songs from any one artist.
  List<Song> rank(
    Iterable<Song> candidates,
    TasteProfile profile, {
    Set<String> exclude = const {},
    int limit = 15,
    int perArtist = 2,
  }) {
    final seen = <String>{...exclude};
    final pool = [
      for (final s in candidates)
        if (seen.add(s.id)) (s, score(s, profile)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));

    final perArtistCount = <String, int>{};
    final picked = <Song>[];
    final overflow = <Song>[];
    for (final (s, _) in pool) {
      final key = s.artistId.isEmpty ? s.artistName : s.artistId;
      final n = perArtistCount[key] ?? 0;
      if (n < perArtist) {
        perArtistCount[key] = n + 1;
        picked.add(s);
      } else {
        overflow.add(s);
      }
      if (picked.length == limit) return picked;
    }
    // Small catalogs: fill up with the best of what the artist cap held back.
    return [...picked, ...overflow].take(limit).toList();
  }

  /// Songs like [seed] — "More like this" and autoplay.
  List<Song> similarTo(
    Song seed,
    Iterable<Song> candidates, {
    Set<String> exclude = const {},
    int limit = 10,
  }) =>
      rank(
        candidates,
        TasteProfile.fromSeeds([(seed, 1)]),
        exclude: {seed.id, ...exclude},
        limit: limit,
        perArtist: 3,
      );
}
