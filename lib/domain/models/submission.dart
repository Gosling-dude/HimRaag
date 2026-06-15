import 'package:equatable/equatable.dart';

/// An artist-contributor's upload/onboarding request, pending admin review.
///
/// This is the future-upload workflow surface: an artist proposes a track (or
/// profile change) which a moderator then approves/rejects. It deliberately
/// carries the same rights metadata the catalog requires, so an approved
/// submission can be promoted into a real song with no missing fields.
class Submission extends Equatable {
  const Submission({
    required this.id,
    required this.submittedBy,
    required this.artistName,
    required this.title,
    required this.region,
    required this.language,
    required this.genre,
    required this.status,
    this.albumTitle = '',
    this.audioUrl = '',
    this.artworkUrl = '',
    this.lyrics = '',
    this.license = '',
    this.attribution = '',
    this.rightsNote = '',
    this.reviewerNote = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String submittedBy;
  final String artistName;
  final String title;
  final String region;
  final String language;
  final String genre;

  /// One of: pending, approved, rejected.
  final String status;

  final String albumTitle;
  final String audioUrl;
  final String artworkUrl;
  final String lyrics;
  final String license;
  final String attribution;

  /// Free-text permission/rights statement from the contributor, stored exactly.
  final String rightsNote;

  /// Moderator's note on the decision.
  final String reviewerNote;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  Submission copyWith({
    String? status,
    String? reviewerNote,
  }) {
    return Submission(
      id: id,
      submittedBy: submittedBy,
      artistName: artistName,
      title: title,
      region: region,
      language: language,
      genre: genre,
      status: status ?? this.status,
      albumTitle: albumTitle,
      audioUrl: audioUrl,
      artworkUrl: artworkUrl,
      lyrics: lyrics,
      license: license,
      attribution: attribution,
      rightsNote: rightsNote,
      reviewerNote: reviewerNote ?? this.reviewerNote,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        submittedBy,
        artistName,
        title,
        region,
        language,
        genre,
        status,
        albumTitle,
        audioUrl,
        artworkUrl,
        lyrics,
        license,
        attribution,
        rightsNote,
        reviewerNote,
        createdAt,
        updatedAt,
      ];
}
