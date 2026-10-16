import 'package:himraag/core/constants/content_constants.dart';
import 'package:himraag/domain/models/song.dart';

String songUrl(String id) => 'https://cdn.example/$id.mp3';

/// An approved, licensed song shaped like the bundled catalog's. The artwork
/// URL is empty so widgets render the offline fallback cover.
Song testSong(
  String id, {
  String region = 'Garhwali',
  int playCount = 0,
  int releaseYear = 2024,
  bool isApproved = true,
}) {
  return Song(
    id: id,
    title: 'Song $id',
    artistId: 'artist',
    artistName: 'Artist',
    albumId: '',
    albumTitle: '',
    audioUrl: songUrl(id),
    artworkUrl: '',
    duration: const Duration(minutes: 3),
    region: region,
    language: region,
    genre: 'Folk',
    releaseYear: releaseYear,
    playCount: playCount,
    tags: const [],
    isApproved: isApproved,
    isDownloadable: true,
    license: LicenseType.licensed,
    approvalStatus:
        isApproved ? ApprovalStatus.approved : ApprovalStatus.pending,
    isPublished: isApproved,
    rightsCleared: true,
  );
}

List<Song> testSongs(int count,
        {String prefix = 's', String region = 'Garhwali'}) =>
    [for (var i = 0; i < count; i++) testSong('$prefix$i', region: region)];

List<String> idsOf(Iterable<Song> songs) => songs.map((s) => s.id).toList();
