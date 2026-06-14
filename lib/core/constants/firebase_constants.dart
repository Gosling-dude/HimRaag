class FirebaseConstants {
  FirebaseConstants._();

  static const String songsCollection = 'songs';
  static const String albumsCollection = 'albums';
  static const String artistsCollection = 'artists';
  static const String playlistsCollection = 'playlists';
  static const String usersCollection = 'users';
  static const String categoriesCollection = 'categories';
  static const String regionsCollection = 'regions';
  static const String featuredCollection = 'featured';
  static const String bannersCollection = 'banners';

  // Firebase Storage paths — reserved for future paid-tier (Blaze plan) integration.
  // Currently unused: audio/artwork URLs are served from external CDN (free tier).
  // static const String audioStoragePath = 'audio';
  // static const String artworkStoragePath = 'artwork';
  // static const String artistImagesPath = 'artists';

  static const String songsTitleField = 'title';
  static const String songsArtistField = 'artistId';
  static const String songsAlbumField = 'albumId';
  static const String songsRegionField = 'region';
  static const String songsLanguageField = 'language';
  static const String songsGenreField = 'genre';
  static const String songsPopularityField = 'playCount';
  static const String songsReleasedAtField = 'releasedAt';
  static const String songsIsApprovedField = 'isApproved';
  static const String songsTagsField = 'tags';
}
