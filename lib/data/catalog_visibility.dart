import '../core/config/app_config.dart';
import '../core/constants/content_constants.dart';
import '../domain/models/album.dart';
import '../domain/models/artist.dart';
import '../domain/models/song.dart';

/// Consumer-facing visibility rules.
///
/// Demo-only content (`license == DEMO_ONLY`) is testable in internal builds but
/// must never reach a public release. These extensions drop demo entries unless
/// [AppConfig.includeDemoContent] is on. Apply them in the consumer providers
/// (NOT in the admin dashboard, which must see everything).
extension SongVisibility on List<Song> {
  List<Song> visibleToConsumers() => AppConfig.includeDemoContent
      ? this
      : where((s) => s.license != LicenseType.demoOnly).toList();
}

extension AlbumVisibility on List<Album> {
  List<Album> visibleToConsumers() => AppConfig.includeDemoContent
      ? this
      : where((a) => a.license != LicenseType.demoOnly).toList();
}

extension ArtistVisibility on List<Artist> {
  List<Artist> visibleToConsumers() => AppConfig.includeDemoContent
      ? this
      // Artists have no license; gate on publish state instead.
      : where((a) => a.isPublished).toList();
}
