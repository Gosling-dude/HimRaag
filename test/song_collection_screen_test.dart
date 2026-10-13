import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:himraag/features/browse/presentation/song_collection_screen.dart';

import 'support/test_songs.dart';

Widget _app(AsyncValue<List<dynamic>> songs, {String? notice}) => ProviderScope(
      child: MaterialApp(
        home: SongCollectionScreen(
          title: 'Trending Now',
          subtitle: 'Most played',
          songs: songs.whenData((l) => l.cast()),
          onRetry: () {},
          notice: notice,
        ),
      ),
    );

void main() {
  testWidgets('shows the title, count, Play/Shuffle and every song',
      (tester) async {
    final songs = [testSong(id: 'a'), testSong(id: 'b'), testSong(id: 'c')];
    await tester.pumpWidget(_app(AsyncData(songs), notice: 'Fallback note'));

    expect(find.text('Trending Now'), findsOneWidget);
    expect(find.text('Most played · 3 songs'), findsOneWidget);
    expect(find.text('Fallback note'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Shuffle'), findsOneWidget);
    expect(find.text('Bedu Pako'), findsNWidgets(3));
  });

  testWidgets('empty and error states', (tester) async {
    await tester.pumpWidget(_app(const AsyncData([])));
    expect(find.text('No songs here yet.'), findsOneWidget);

    await tester.pumpWidget(_app(AsyncError('boom', StackTrace.empty)));
    expect(find.text('Failed to load songs'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
