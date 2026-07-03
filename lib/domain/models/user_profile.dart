import 'package:equatable/equatable.dart';

/// Per-user personalization profile. Stored offline-first in Hive (works for
/// guests + offline) and mirrored to Firestore `users/{uid}` when a Firebase
/// user (anonymous or Google) exists. This is consumer-private data — kept
/// entirely separate from admin/catalog documents.
class UserProfile extends Equatable {
  const UserProfile({
    this.preferredRegions = const [],
    this.preferredLanguages = const [],
    this.preferredGenres = const [],
    this.followedArtistIds = const [],
    this.onboardingCompleted = false,
    this.continueListening,
  });

  final List<String> preferredRegions;
  final List<String> preferredLanguages;
  final List<String> preferredGenres;
  final List<String> followedArtistIds;
  final bool onboardingCompleted;

  /// Last partially-played track, for the "Continue Listening" rail.
  final ContinueListening? continueListening;

  bool get hasPreferences =>
      preferredRegions.isNotEmpty ||
      preferredLanguages.isNotEmpty ||
      preferredGenres.isNotEmpty;

  UserProfile copyWith({
    List<String>? preferredRegions,
    List<String>? preferredLanguages,
    List<String>? preferredGenres,
    List<String>? followedArtistIds,
    bool? onboardingCompleted,
    ContinueListening? continueListening,
    bool clearContinueListening = false,
  }) {
    return UserProfile(
      preferredRegions: preferredRegions ?? this.preferredRegions,
      preferredLanguages: preferredLanguages ?? this.preferredLanguages,
      preferredGenres: preferredGenres ?? this.preferredGenres,
      followedArtistIds: followedArtistIds ?? this.followedArtistIds,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      continueListening: clearContinueListening
          ? null
          : (continueListening ?? this.continueListening),
    );
  }

  Map<String, dynamic> toMap() => {
        'preferredRegions': preferredRegions,
        'preferredLanguages': preferredLanguages,
        'preferredGenres': preferredGenres,
        'followedArtistIds': followedArtistIds,
        'onboardingCompleted': onboardingCompleted,
        if (continueListening != null)
          'continueListening': continueListening!.toMap(),
      };

  static UserProfile fromMap(Map<String, dynamic>? map) {
    if (map == null) return const UserProfile();
    List<String> list(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    final cl = map['continueListening'];
    return UserProfile(
      preferredRegions: list(map['preferredRegions']),
      preferredLanguages: list(map['preferredLanguages']),
      preferredGenres: list(map['preferredGenres']),
      followedArtistIds: list(map['followedArtistIds']),
      onboardingCompleted: map['onboardingCompleted'] == true,
      continueListening: cl is Map
          ? ContinueListening.fromMap(Map<String, dynamic>.from(cl))
          : null,
    );
  }

  @override
  List<Object?> get props => [
        preferredRegions,
        preferredLanguages,
        preferredGenres,
        followedArtistIds,
        onboardingCompleted,
        continueListening,
      ];
}

class ContinueListening extends Equatable {
  const ContinueListening({
    required this.songId,
    required this.title,
    required this.artistName,
    required this.artworkUrl,
    required this.audioUrl,
    required this.positionMs,
    required this.durationMs,
    required this.updatedAt,
  });

  final String songId;
  final String title;
  final String artistName;
  final String artworkUrl;
  final String audioUrl;
  final int positionMs;
  final int durationMs;
  final DateTime updatedAt;

  double get progress =>
      durationMs <= 0 ? 0 : (positionMs / durationMs).clamp(0.0, 1.0);

  Map<String, dynamic> toMap() => {
        'songId': songId,
        'title': title,
        'artistName': artistName,
        'artworkUrl': artworkUrl,
        'audioUrl': audioUrl,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  static ContinueListening fromMap(Map<String, dynamic> m) => ContinueListening(
        songId: m['songId']?.toString() ?? '',
        title: m['title']?.toString() ?? '',
        artistName: m['artistName']?.toString() ?? '',
        artworkUrl: m['artworkUrl']?.toString() ?? '',
        audioUrl: m['audioUrl']?.toString() ?? '',
        positionMs: (m['positionMs'] as num?)?.toInt() ?? 0,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
            (m['updatedAt'] as num?)?.toInt() ?? 0),
      );

  @override
  List<Object?> get props =>
      [songId, positionMs, durationMs, updatedAt];
}
