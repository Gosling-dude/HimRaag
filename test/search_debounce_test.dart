import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himraag/data/local/local_catalog_datasource.dart';
import 'package:himraag/data/remote/algolia_search_datasource.dart';
import 'package:himraag/data/remote/firestore_search_datasource.dart';
import 'package:himraag/domain/models/album.dart';
import 'package:himraag/domain/models/artist.dart';
import 'package:himraag/domain/models/song.dart';
import 'package:himraag/features/search/providers/search_providers.dart';

/// Counts calls and records the queries that actually reached the datasource.
class _CountingSearchDatasource implements FirestoreSearchDatasource {
  int calls = 0;
  final queries = <String>[];

  @override
  Future<SearchResult> search(String query, {SearchFilters? filters}) async {
    calls++;
    queries.add(query);
    return SearchResult(
      songs: const [],
      artists: const [],
      albums: const [],
      query: query,
    );
  }

  // The provider only ever calls `search`. Everything else on the interface is
  // routed to noSuchMethod so this fake does not have to track upstream
  // signature changes on methods it never exercises.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Local catalog stub — returns nothing and never touches the asset bundle.
class _EmptyLocalCatalog implements LocalCatalogDatasource {
  int calls = 0;

  @override
  Future<({List<Song> songs, List<Album> albums, List<Artist> artists})> search(
    String query,
  ) async {
    calls++;
    return (songs: <Song>[], albums: <Album>[], artists: <Artist>[]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('search debounce', () {
    late _CountingSearchDatasource remote;
    late _EmptyLocalCatalog local;
    late ProviderContainer container;

    setUp(() {
      remote = _CountingSearchDatasource();
      local = _EmptyLocalCatalog();
      container = ProviderContainer(overrides: [
        firestoreSearchProvider.overrideWithValue(remote),
        localCatalogProvider.overrideWithValue(local),
      ]);
      // Keep the provider alive across query changes, mirroring the search
      // screen which stays subscribed for the whole typing session.
      container.listen(searchResultsProvider, (_, __) {}, fireImmediately: true);
    });

    tearDown(() => container.dispose());

    test('a burst of keystrokes issues exactly one backend search', () async {
      // Simulate typing "pahadi" one character at a time with no pause.
      for (final q in ['p', 'pa', 'pah', 'paha', 'pahad', 'pahadi']) {
        container.read(searchQueryProvider.notifier).state = q;
      }

      // Nothing should have fired yet — the debounce window is still open.
      expect(remote.calls, 0,
          reason: 'no search may be issued before the debounce elapses');

      await container.read(searchResultsProvider.future);

      expect(remote.calls, 1,
          reason: 'six keystrokes must collapse into a single Firestore search');
      expect(remote.queries, ['pahadi'],
          reason: 'only the final query should be searched');
      expect(local.calls, 1,
          reason: 'the local catalog scan is debounced along with the remote one');
    });

    test('a settled query still returns its results', () async {
      container.read(searchQueryProvider.notifier).state = 'pahadi';
      final result = await container.read(searchResultsProvider.future);

      expect(result.query, 'pahadi');
      expect(remote.calls, 1);
    });

    test('typing then clearing does not leave a pending search', () async {
      container.read(searchQueryProvider.notifier).state = 'pahadi';
      container.read(searchQueryProvider.notifier).state = '';

      final result = await container.read(searchResultsProvider.future);

      expect(result.songs, isEmpty);
      expect(remote.calls, 0,
          reason: 'an abandoned query must never reach the backend');
    });

    test('a pause between words issues one search per settled query', () async {
      container.read(searchQueryProvider.notifier).state = 'pahadi';
      await container.read(searchResultsProvider.future);

      container.read(searchQueryProvider.notifier).state = 'pahadi folk';
      await container.read(searchResultsProvider.future);

      expect(remote.calls, 2);
      expect(remote.queries, ['pahadi', 'pahadi folk']);
    });
  });
}
