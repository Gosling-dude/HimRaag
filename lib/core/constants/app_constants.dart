class AppConstants {
  AppConstants._();

  static const String appName = 'HimRaag';
  static const String appTagline = 'Pahadi Music, Heart of the Hills';
  static const String packageName = 'com.himraag.app';

  static const String privacyPolicyUrl = 'https://himraag.app/privacy';
  static const String termsUrl = 'https://himraag.app/terms';
  static const String supportEmail = 'support@himraag.app';

  static const int maxDownloadsCount = 500;
  static const int maxPlaylistSongs = 200;
  static const int maxRecentlyPlayed = 50;
  static const int homePageBatchSize = 20;
  static const int searchPageSize = 30;

  static const Duration audioSeekDebounce = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration snackBarDuration = Duration(seconds: 3);

  static const double minPlayerHeight = 64.0;
  static const double bottomNavHeight = 60.0;
  static const double maxPlayerHeight = 0.95;

  static const List<String> pahadiRegions = [
    'Garhwali',
    'Kumaoni',
    'Jaunsari',
    'Himachali',
    'Kinnauri',
    'Sirmauri',
  ];

  static const List<String> pahadiGenres = [
    'Folk',
    'Devotional',
    'Festival',
    'Wedding',
    'Seasonal',
    'Instrumental',
    'Contemporary Folk',
  ];

  static const List<String> festivals = [
    'Harela',
    'Phool Dei',
    'Basant Panchami',
    'Uttarayani',
    'Genge',
    'Bikhauti',
    'Jhanda Mela',
  ];
}
