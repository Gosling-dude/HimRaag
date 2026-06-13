import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return datasource.search(query, filters: filters);
});

final activeFilterTabProvider = StateProvider<String>((ref) => 'All');
