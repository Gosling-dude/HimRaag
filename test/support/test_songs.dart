import 'package:himraag/domain/models/song.dart';

Song testSong({
  String id = 'bedu-pako',
  String audioUrl = 'https://pub-abc.r2.dev/audio/bedu-pako.mp3',
  String? localPath,
  Duration duration = const Duration(minutes: 4),
}) =>
    Song(
      id: id,
      title: 'Bedu Pako',
      artistId: 'negi',
      artistName: 'Narendra Singh Negi',
      albumId: '',
      albumTitle: '',
      audioUrl: audioUrl,
      artworkUrl: 'https://pub-abc.r2.dev/artwork/bedu-pako.png',
      duration: duration,
      region: 'Garhwali',
      language: 'Garhwali',
      genre: 'Folk',
      releaseYear: 1990,
      playCount: 0,
      tags: const [],
      isApproved: true,
      isDownloadable: true,
      localPath: localPath,
    );
