import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';

// SearchFilters and SearchResult remain here as shared data classes.
// Algolia has been replaced with FirestoreSearchDatasource (zero cost, no external service).

class SearchFilters {
  const SearchFilters({
    this.region,
    this.language,
    this.genre,
    this.mood,
    this.minYear,
    this.maxYear,
  });

  final String? region;
  final String? language;
  final String? genre;
  final String? mood;
  final int? minYear;
  final int? maxYear;

  bool get isEmpty =>
      region == null &&
      language == null &&
      genre == null &&
      mood == null &&
      minYear == null &&
      maxYear == null;
}

class SearchResult {
  const SearchResult({
    required this.songs,
    required this.artists,
    required this.albums,
    required this.query,
  });

  final List<Song> songs;
  final List<Artist> artists;
  final List<Album> albums;
  final String query;

  bool get isEmpty => songs.isEmpty && artists.isEmpty && albums.isEmpty;
}
