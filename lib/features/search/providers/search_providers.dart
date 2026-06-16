import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/catalog_visibility.dart';
import '../../../data/local/local_catalog_datasource.dart';
import '../../../data/remote/algolia_search_datasource.dart';
import '../../../data/remote/firestore_search_datasource.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/song.dart';

export '../../../data/remote/algolia_search_datasource.dart' show SearchFilters;

/// Union of local (imported) + remote search hits, de-duplicated by id with
/// local first.
List<T> _mergeById<T>(List<T> local, List<T> remote, String Function(T) id) {
  final seen = <String>{};
  final out = <T>[];
  for (final item in [...local, ...remote]) {
    if (seen.add(id(item))) out.add(item);
  }
  return out;
}

final searchQueryProvider = StateProvider<String>((ref) => '');
final searchFiltersProvider =
    StateProvider<SearchFilters>((ref) => const SearchFilters());

final searchResultsProvider = FutureProvider<SearchResult>((ref) async {
  final query = ref.watch(searchQueryProvider);
  final filters = ref.watch(searchFiltersProvider);

  if (query.trim().isEmpty) {
    return const SearchResult(songs: [], artists: [], albums: [], query: '');
  }

  final datasource = ref.watch(firestoreSearchProvider);
  final result = await datasource.search(query, filters: filters);

  // Merge locally-imported (bundled) catalog matches so imported songs are
  // searchable by name even when they are not in Firestore.
  final local = await ref.watch(localCatalogProvider).search(query);

  // Respect the demo-content gate in search results too. Imported items are
  // LICENSED so they survive the filter in every build mode.
  return SearchResult(
    songs: _mergeById<Song>(local.songs, result.songs, (s) => s.id)
        .visibleToConsumers(),
    artists: _mergeById<Artist>(local.artists, result.artists, (a) => a.id)
        .visibleToConsumers(),
    albums: _mergeById<Album>(local.albums, result.albums, (a) => a.id)
        .visibleToConsumers(),
    query: result.query,
  );
});

final activeFilterTabProvider = StateProvider<String>((ref) => 'All');
