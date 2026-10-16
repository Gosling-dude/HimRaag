class AppConstants {
  AppConstants._();

  static const String appName = 'HimRaag';
  static const String appTagline = 'Pahadi Music, Heart of the Hills';
  static const String packageName = 'com.sumitchauhan.himraag';

  // Hosted legal pages. These must match the URLs entered in Play Console
  // (App content → Privacy policy, Data safety → account deletion URL).
  static const String privacyPolicyUrl =
      'https://gosling-dude.github.io/himraag-legal/privacy.html';
  static const String termsUrl =
      'https://gosling-dude.github.io/himraag-legal/terms.html';
  static const String accountDeletionUrl =
      'https://gosling-dude.github.io/himraag-legal/delete-account.html';
  static const String supportEmail = 'support@himraag.app';

  static const int maxDownloadsCount = 500;
  static const int maxPlaylistSongs = 200;
  static const int maxRecentlyPlayed = 50;
  static const int homePageBatchSize = 20;
  static const int searchPageSize = 30;

  static const Duration audioSeekDebounce = Duration(milliseconds: 300);
  static const Duration splashDuration = Duration(seconds: 2);
  static const Duration snackBarDuration = Duration(seconds: 3);

  /// How long each Home banner slide stays before advancing on its own.
  static const Duration homeBannerAutoAdvanceInterval = Duration(seconds: 3);

  /// The slide animation between Home banner slides.
  static const Duration homeBannerSlideDuration = Duration(milliseconds: 350);

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
