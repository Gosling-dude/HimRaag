import 'package:flutter_test/flutter_test.dart';

import 'package:himraag/data/remote/home_feed_datasource.dart';

Map<String, dynamic> _song(String title, {String region = 'Garhwali'}) => {
      'title': title,
      'artistName': 'Artist',
      'audioUrl': 'https://pub-abc.r2.dev/audio/$title.mp3',
      'region': region,
      'playCount': 7,
      'isApproved': true,
      'license': 'LICENSED',
    };

void main() {
  final feedDoc = <String, dynamic>{
    'version': 1,
    'songs': {
      'a': _song('a'),
      'b': _song('b', region: 'Kumaoni'),
      'c': _song('c'),
    },
    'featuredSongIds': ['b', 'a'],
    'trendingSongIds': ['c', 'missing', 'a'],
    'newReleaseIds': ['a'],
    'regionSongIds': {
      'Garhwali': ['a', 'c'],
      'Kumaoni': ['b'],
    },
    'albums': [
      {'id': 'al1', 'title': 'Album One', 'isApproved': true},
      {'title': 'no id — skipped'},
    ],
    'artists': [
      {'id': 'ar1', 'name': 'Artist One', 'isPublished': true},
    ],
  };

  test('parses rows in server order, sharing song objects', () {
    final feed = HomeFeed.fromMap(feedDoc)!;
    expect(feed.featuredSongs.map((s) => s.id), ['b', 'a']);
    expect(feed.featuredSongs.first.playCount, 7);
    expect(feed.newReleases.single.title, 'a');
    expect(feed.regionSongs['Garhwali']!.map((s) => s.id), ['a', 'c']);
    expect(feed.regionSongs['Kumaoni']!.single.region, 'Kumaoni');
  });

  test('skips ids with no song entry', () {
    final feed = HomeFeed.fromMap(feedDoc)!;
    expect(feed.trendingSongs.map((s) => s.id), ['c', 'a']);
  });

  test('parses albums and artists, dropping entries without an id', () {
    final feed = HomeFeed.fromMap(feedDoc)!;
    expect(feed.albums.single.title, 'Album One');
    expect(feed.artists.single.name, 'Artist One');
  });

  test('rejects unknown versions and malformed docs (app falls back)', () {
    expect(HomeFeed.fromMap({...feedDoc, 'version': 2}), isNull);
    expect(HomeFeed.fromMap({'version': 1}), isNull);
    expect(HomeFeed.fromMap({}), isNull);
  });

  test('tolerates missing optional rows', () {
    final feed = HomeFeed.fromMap({'version': 1, 'songs': {}})!;
    expect(feed.featuredSongs, isEmpty);
    expect(feed.regionSongs, isEmpty);
    expect(feed.albums, isEmpty);
  });
}
