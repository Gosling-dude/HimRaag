import 'package:hive_flutter/hive_flutter.dart';

import 'models/hive_song.dart';
import 'models/hive_download_task.dart';
import 'models/hive_recently_played.dart';

class HiveBoxes {
  HiveBoxes._();

  static const String downloadsBox = 'downloads';
  static const String recentlyPlayedBox = 'recently_played';
  static const String favoritesBox = 'favorites';
  static const String playlistsBox = 'playlists';
  static const String settingsBox = 'settings';
  static const String cachedSongsBox = 'cached_songs';

  static Future<void> registerAdapters() async {
    Hive.registerAdapter(HiveSongAdapter());
    Hive.registerAdapter(HiveDownloadTaskAdapter());
    Hive.registerAdapter(HiveRecentlyPlayedAdapter());
  }

  static Future<void> openBoxes() async {
    await Hive.openBox<HiveSong>(downloadsBox);
    await Hive.openBox<HiveRecentlyPlayed>(recentlyPlayedBox);
    await Hive.openBox<String>(favoritesBox);
    await Hive.openBox<HiveDownloadTask>(cachedSongsBox);
    await Hive.openBox(settingsBox);
  }

  static Box<HiveSong> get downloads => Hive.box<HiveSong>(downloadsBox);
  static Box<HiveRecentlyPlayed> get recentlyPlayed =>
      Hive.box<HiveRecentlyPlayed>(recentlyPlayedBox);
  static Box<String> get favorites => Hive.box<String>(favoritesBox);
  static Box<HiveDownloadTask> get cachedSongs =>
      Hive.box<HiveDownloadTask>(cachedSongsBox);
  static Box get settings => Hive.box(settingsBox);
}
