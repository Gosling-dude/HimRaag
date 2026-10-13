import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/display/consumer_labels.dart';
import '../../data/catalog_visibility.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import '../home/providers/home_providers.dart';

/// Full lists behind Home's "See All" buttons. Home rows show the first
/// handful; these pages show the whole thing.

final allTrendingSongsProvider = FutureProvider<List<Song>>((ref) async {
  final songs =
      await ref.watch(songDatasourceProvider).getTrendingSongs(limit: 50);
  return songs.visibleToConsumers();
});

final allNewReleasesProvider = FutureProvider<List<Song>>((ref) async {
  final songs =
      await ref.watch(songDatasourceProvider).getNewReleases(limit: 50);
  return songs.visibleToConsumers();
});

final allAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final albums = await ref.watch(albumDatasourceProvider).getAllAlbums();
  return albums.visibleToConsumers();
});

/// Artists with a photo first, then by number of songs; the "Pahadi Folk"
/// catch-all isn't a real artist, so it's left out.
final allArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final artists = (await ref.watch(artistDatasourceProvider).getAllArtists())
      .visibleToConsumers()
      .where((a) => !a.isFolkCollective)
      .toList();
  return [
    ...artists.where((a) => a.imageUrl.trim().isNotEmpty),
    ...artists.where((a) => a.imageUrl.trim().isEmpty),
  ];
});

/// Songs for one festival: those whose title or tags mention it. Few songs
/// are tagged by festival yet, so [FestivalSongs.exact] says whether these
/// are matches or the general Festival-genre fallback.
class FestivalSongs {
  const FestivalSongs(this.songs, {required this.exact});
  final List<Song> songs;
  final bool exact;
}

final festivalSongsProvider =
    FutureProvider.family<FestivalSongs, String>((ref, festival) async {
  final songs = (await ref
          .watch(songDatasourceProvider)
          .getSongsByGenre('Festival', limit: 100))
      .visibleToConsumers();
  final key = festival.toLowerCase();
  final matches = songs
      .where((s) =>
          s.title.toLowerCase().contains(key) ||
          s.tags.any((t) => t.toLowerCase() == key))
      .toList();
  return matches.isNotEmpty
      ? FestivalSongs(matches, exact: true)
      : FestivalSongs(songs, exact: false);
});
