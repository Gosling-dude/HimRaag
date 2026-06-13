import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/playlist.dart';
import '../../../../domain/models/song.dart';
import '../../../home/providers/home_providers.dart';
import '../../../library/presentation/widgets/song_list_tile.dart';
import '../../../player/providers/player_providers.dart';

final _playlistDetailProvider =
    FutureProvider.family<Playlist?, String>((ref, playlistId) async {
  final doc = await FirebaseFirestore.instance
      .collection('playlists')
      .doc(playlistId)
      .get();
  if (!doc.exists) return null;
  final data = doc.data()!;
  return Playlist(
    id: doc.id,
    title: data['title'] as String? ?? '',
    songIds: List<String>.from(data['songIds'] as List? ?? []),
    createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    description: data['description'] as String?,
    artworkUrl: data['artworkUrl'] as String?,
    isUserCreated: data['isUserCreated'] as bool? ?? false,
    isPublic: data['isPublic'] as bool? ?? true,
    ownerId: data['ownerId'] as String?,
  );
});

final playlistSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, playlistId) async {
  final playlist = await ref.watch(_playlistDetailProvider(playlistId).future);
  if (playlist == null || playlist.songIds.isEmpty) return [];
  return ref.watch(songDatasourceProvider).getSongsByIds(playlist.songIds);
});

class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistAsync = ref.watch(_playlistDetailProvider(playlistId));
    final songsAsync = ref.watch(playlistSongsProvider(playlistId));

    return Scaffold(
      appBar: AppBar(
        title: playlistAsync.when(
          data: (p) => Text(p?.title ?? 'Playlist'),
          loading: () => const Text('Playlist'),
          error: (_, __) => const Text('Playlist'),
        ),
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text('Failed to load playlist'),
              TextButton(
                onPressed: () {
                  ref.invalidate(_playlistDetailProvider(playlistId));
                  ref.invalidate(playlistSongsProvider(playlistId));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (songs) => songs.isEmpty
            ? const Center(child: Text('Playlist is empty'))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: songs.length,
                itemBuilder: (context, index) => SongListTile(
                  song: songs[index],
                  onTap: () => ref.read(playerControllerProvider).playSong(
                        songs[index],
                        queue: songs,
                        queueIndex: index,
                      ),
                ),
              ),
      ),
    );
  }
}
