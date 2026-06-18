import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import '../../domain/models/song.dart';
import '../constants/content_constants.dart';

/// Consumer-facing label sanitizers (defense-in-depth).
///
/// Internal moderation sentinels (`Unknown Artist`, [ContentConstants.needsReview],
/// `Imported Recordings`) must NEVER reach Home/Search/Player/Artist/Album. The
/// catalog data is already cleaned, but these getters guarantee a professional
/// label even if a stale or freshly-imported record slips through. They are
/// deliberately scoped to consumer widgets — admin/artist dashboards keep the
/// raw fields so the metadata-review workflow still works.
const String _kFolkArtist = 'Pahadi Folk';
const String _kFolkAlbum = 'Pahadi Folk Collection';
const String _kFallbackRegion = 'Pahadi';
const String _kUnknownArtist = 'Unknown Artist';
const String _kImportedAlbum = 'Imported Recordings';

String _artist(String v) {
  final t = v.trim();
  return (t.isEmpty || t == _kUnknownArtist) ? _kFolkArtist : t;
}

String _region(String v) {
  final t = v.trim();
  return (t.isEmpty || t == ContentConstants.needsReview) ? _kFallbackRegion : t;
}

String _album(String v) {
  final t = v.trim();
  return (t.isEmpty || t == _kImportedAlbum) ? _kFolkAlbum : t;
}

extension SongLabels on Song {
  String get displayArtist => _artist(artistName);
  String get displayRegion => _region(region);
  String get displayAlbum => _album(albumTitle);
}

extension AlbumLabels on Album {
  String get displayArtist => _artist(artistName);
  String get displayRegion => _region(region);
  String get displayTitle => _album(title);
}

extension ArtistLabels on Artist {
  String get displayName => _artist(name);
  String get displayRegion => _region(region);
}
