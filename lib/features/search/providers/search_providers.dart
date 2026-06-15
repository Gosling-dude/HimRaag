import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/catalog_visibility.dart';
import '../../../data/remote/algolia_search_datasource.dart';
import '../../../data/remote/firestore_search_datasource.dart';

export '../../../data/remote/algolia_search_datasource.dart' show SearchFilters;

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
  // Respect the demo-content gate in search results too.
  return SearchResult(
    songs: result.songs.visibleToConsumers(),
    artists: result.artists.visibleToConsumers(),
    albums: result.albums.visibleToConsumers(),
    query: result.query,
  );
});

final activeFilterTabProvider = StateProvider<String>((ref) => 'All');
