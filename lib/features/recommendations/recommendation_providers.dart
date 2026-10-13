import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../data/catalog_visibility.dart';
import '../../data/remote/firebase_song_datasource.dart';
import '../../data/services/audio_player_service.dart';
import '../../domain/models/song.dart';
import '../home/providers/home_providers.dart';
import '../library/providers/library_providers.dart';
import '../profile/settings_providers.dart';
import 'recommender.dart';

/// Full song docs by id, cached for the session. Recently-played and queue
/// entries only carry title/artist, so scoring needs the real record.
class SongLookup {
  SongLookup(this._ds);

  final FirebaseSongDatasource _ds;
  final Map<String, Song?> _cache = {};

  Future<List<Song>> byIds(Iterable<String> ids) async {
    final missing = ids.where((id) => !_cache.containsKey(id)).toSet().toList();
    if (missing.isNotEmpty) {
      final found = await _ds.getSongsByIds(missing);
      for (final id in missing) {
        _cache[id] = null;
      }
      for (final s in found) {
        _cache[s.id] = s;
      }
    }
    return [
      for (final id in ids)
        if (_cache[id] != null) _cache[id]!
    ];
  }

  Future<Song?> byId(String id) async => (await byIds([id])).firstOrNull;
}

final songLookupProvider = Provider<SongLookup>(
    (ref) => SongLookup(ref.watch(songDatasourceProvider)));

const _recommender = Recommender();

/// How many of the latest plays shape the profile (and are kept out of
/// "Recommended for you" — the listener has heard them recently).
const _recentSeeds = 20;

/// The listener's taste: favorites count most, then downloads, then recent
/// plays (newest strongest). Read once per refresh — not on every play — so
/// the Home row doesn't reshuffle mid-session.
final tasteSeedsProvider = FutureProvider<List<(Song, double)>>((ref) async {
  final favorites = ref.read(favoritesProvider).take(20).toList();
  final recent = ref.read(recentlyPlayedProvider).take(_recentSeeds).toList();
  final downloads = ref.read(libraryProvider).downloads;

  final full = {
    for (final s in await ref
        .read(songLookupProvider)
        .byIds({...favorites, ...recent.map((s) => s.id)}))
      s.id: s,
  };
  return [
    for (final id in favorites)
      if (full[id] != null) (full[id]!, 3.0),
    for (final s in downloads) (full[s.id] ?? s, 2.0),
    for (final (i, s) in recent.indexed)
      if (full[s.id] != null) (full[s.id]!, 1.0 - 0.7 * i / _recentSeeds),
  ];
});

/// Home "Recommended for you". New listeners (no history yet) get the most
/// popular songs from the region picked on Home, or trending overall.
final recommendedSongsProvider = FutureProvider<List<Song>>((ref) async {
  final ds = ref.watch(songDatasourceProvider);
  final seeds = await ref.watch(tasteSeedsProvider.future);

  if (seeds.isEmpty) {
    final region = ref.watch(selectedRegionProvider);
    final popular = region == 'All'
        ? await ref.watch(trendingSongsProvider.future)
        : await ds.getSongsByRegion(region);
    return popular.visibleToConsumers().take(50).toList();
  }

  final profile = TasteProfile.fromSeeds(seeds);
  final queries = <Future<List<Song>>>[
    for (final a in TasteProfile.top(profile.artists, 3))
      ds.getSongsByArtist(a, limit: 12),
    for (final r in TasteProfile.top(profile.regions, 2))
      ds.getSongsByRegion(_titleCase(r), limit: 30),
    for (final g in TasteProfile.top(profile.genres, 1))
      ds.getSongsByGenre(_titleCase(g), limit: 20),
  ];
  final candidates = (await Future.wait(queries)).expand((l) => l);
  final heard = {
    ...ref.read(recentlyPlayedProvider).take(_recentSeeds).map((s) => s.id),
    ...ref.read(favoritesProvider),
  };
  // Enough for the full "Recommended for You" page; Home shows the top 15.
  return _recommender.rank(candidates.toList().visibleToConsumers(), profile,
      exclude: heard, limit: 50);
});

/// "More like this" for a song id: same artist and same region, ranked.
final similarSongsProvider =
    FutureProvider.family<List<Song>, String>((ref, songId) async {
  final ds = ref.watch(songDatasourceProvider);
  final seed = await ref.read(songLookupProvider).byId(songId);
  if (seed == null) return const [];
  final pools = await Future.wait([
    if (seed.artistId.isNotEmpty) ds.getSongsByArtist(seed.artistId, limit: 15),
    if (seed.region.isNotEmpty) ds.getSongsByRegion(seed.region, limit: 30),
    if (seed.genre.isNotEmpty) ds.getSongsByGenre(seed.genre, limit: 15),
  ]);
  return _recommender.similarTo(
      seed, pools.expand((l) => l).toList().visibleToConsumers());
});

/// Keeps the music going: when the last song in the queue starts (and repeat
/// is off), similar songs are appended so playback continues seamlessly.
/// Watched once from the app root, like play tracking.
final autoplayProvider = Provider<void>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  String? extendedAfter; // song id we already extended the queue after

  final sub = service.sequenceStateStream.listen((state) {
    final seq = state?.effectiveSequence;
    final index = state?.currentIndex;
    if (seq == null || index == null || seq.isEmpty) return;
    if (index != seq.length - 1) return;
    if (service.player.loopMode != LoopMode.off) return;
    if (!ref.read(autoplayEnabledProvider)) return;
    final current = service.currentSongId;
    if (current == null || current == extendedAfter) return;
    extendedAfter = current;

    unawaited(() async {
      try {
        final queued = service.getCurrentQueue().map((s) => s.id).toSet();
        final next = (await ref.read(similarSongsProvider(current).future))
            .where((s) => !queued.contains(s.id))
            .take(5);
        for (final s in next) {
          await service.addToQueue(s);
        }
        debugPrint('[AUTOPLAY] queued ${next.length} songs after $current');
      } catch (e) {
        debugPrint('[AUTOPLAY] failed: $e');
      }
    }());
  });
  ref.onDispose(sub.cancel);
});

/// Profile keys are lower-cased; Firestore region/genre values are Title Case.
String _titleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
    .join(' ');
