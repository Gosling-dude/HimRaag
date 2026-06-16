import '../constants/app_constants.dart';
import '../constants/content_constants.dart';

/// Result of validating one raw track record.
class TrackValidationResult {
  TrackValidationResult({
    required this.errors,
    required this.warnings,
    required this.normalized,
  });

  final List<String> errors;
  final List<String> warnings;

  /// The normalized record (canonicalized taxonomy, derived ids/slug, coerced
  /// types). Only meaningful when [ok] is true, but always populated.
  final Map<String, dynamic> normalized;

  bool get ok => errors.isEmpty;
}

/// Canonical metadata validation + normalization for the admin dashboard.
///
/// Dart mirror of `scripts/lib/validator.js` — keep the two in sync. Pure (no
/// network, no Firestore) so it can run synchronously in the import preview UI.
class MetadataValidator {
  MetadataValidator._();

  static const _required = [
    'title',
    'artistName',
    'region',
    'language',
    'genre',
    'durationMs',
    'artworkUrl',
    'audioUrl',
    'license',
    'approvalStatus',
  ];

  static String slugify(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '')
        .replaceAll(RegExp(r'-{2,}'), '-');
  }

  static String songId(String artistName, String title) =>
      'song_${slugify(artistName)}__${slugify(title)}'.replaceAll('-', '_');

  static String artistId(String name) =>
      'artist_${slugify(name)}'.replaceAll('-', '_');

  static String albumId(String artistName, String title) =>
      'album_${slugify(artistName)}__${slugify(title)}'.replaceAll('-', '_');

  static String _canon(String? value, List<String> allowed) {
    final v = (value ?? '').trim();
    return allowed.firstWhere(
      (a) => a.toLowerCase() == v.toLowerCase(),
      orElse: () => v,
    );
  }

  static bool looksLikeUrl(String? v) =>
      RegExp(r'^https?://.+', caseSensitive: false).hasMatch(v ?? '');

  /// Audio may be remote (http/https) or bundled locally (Flutter asset/file).
  /// Mirrors `looksLikeAudioUrl` in `scripts/lib/validator.js`.
  static bool looksLikeAudioUrl(String? v) =>
      RegExp(r'^(https?|asset|file)://.+', caseSensitive: false)
          .hasMatch(v ?? '');

  static int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  /// Validate + normalize a single raw record (e.g. a parsed CSV row / JSON map).
  static TrackValidationResult validateTrack(Map<String, dynamic> raw) {
    final errors = <String>[];
    final warnings = <String>[];
    final t = Map<String, dynamic>.from(raw);

    final durationMs = _toInt(t['durationMs']);
    final releaseYear = _toInt(t['releaseYear']);
    final playCount = _toInt(t['playCount']) ?? 0;

    for (final f in _required) {
      final val = t[f];
      if (val == null || (val is String && val.trim().isEmpty)) {
        errors.add('missing required field "$f"');
      }
    }

    final region = _canon(t['region'] as String?, AppConstants.pahadiRegions);
    final language = _canon(t['language'] as String?, ContentConstants.languages);
    final genre = _canon(t['genre'] as String?, AppConstants.pahadiGenres);

    if (region.isNotEmpty &&
        region != ContentConstants.needsReview &&
        !AppConstants.pahadiRegions.contains(region)) {
      errors.add('region "$region" is not an allowed Pahadi region');
    } else if (region == ContentConstants.needsReview) {
      warnings.add('region is "Needs Review" — assign a region in the dashboard');
    }
    if (language.isNotEmpty &&
        language != ContentConstants.needsReview &&
        !ContentConstants.languages.contains(language)) {
      errors.add('language "$language" is not an allowed language');
    } else if (language == ContentConstants.needsReview) {
      warnings.add('language is "Needs Review" — assign a language in the dashboard');
    }
    if (genre.isNotEmpty && !AppConstants.pahadiGenres.contains(genre)) {
      warnings.add('genre "$genre" is not in the standard genre list');
    }

    if (durationMs == null || durationMs <= 0) {
      errors.add('durationMs must be a positive number (no 00:00 tracks)');
    }

    final licenseWire = (t['license'] as String?)?.trim() ?? '';
    final license = LicenseType.values
        .where((l) => l.wire == licenseWire)
        .cast<LicenseType?>()
        .firstOrNull;
    if (license == null) {
      errors.add('license "$licenseWire" is unknown — rights unclear, rejected');
    } else {
      t['rightsCleared'] = license.cleared;
      final attribution = (t['attribution'] as String?)?.trim() ?? '';
      if (license.requiresAttribution && attribution.isEmpty) {
        errors.add('license "$licenseWire" requires a non-empty attribution');
      }
      if (license == LicenseType.demoOnly && t['isPublished'] == true) {
        errors.add('DEMO_ONLY content cannot be published');
      }
    }

    final status = (t['approvalStatus'] as String?)?.trim() ?? '';
    final validStatuses = ApprovalStatus.values.map((s) => s.wire).toList();
    if (status.isNotEmpty && !validStatuses.contains(status)) {
      errors.add('approvalStatus "$status" is invalid');
    }

    if (!looksLikeAudioUrl(t['audioUrl'] as String?)) {
      errors.add('audioUrl must be an http(s), asset:// or file:// URL');
    }
    if (!looksLikeUrl(t['artworkUrl'] as String?)) {
      errors.add('artworkUrl must be an http(s) URL');
    }

    if (((t['lyrics'] as String?) ?? '').trim().isEmpty) {
      warnings.add('no lyrics provided');
    }
    if (releaseYear == null) warnings.add('no releaseYear provided');

    // Derived / normalized fields.
    final title = ((t['title'] as String?) ?? '').trim();
    final artistName = ((t['artistName'] as String?) ?? '').trim();
    t['title'] = title;
    t['artistName'] = artistName;
    t['region'] = region;
    t['language'] = language;
    t['genre'] = genre;
    t['durationMs'] = durationMs ?? 0;
    t['releaseYear'] = releaseYear ?? DateTime.now().year;
    t['playCount'] = playCount;
    t['slug'] = (t['slug'] as String?)?.isNotEmpty == true
        ? t['slug']
        : slugify(title);
    t['id'] =
        (t['id'] as String?)?.isNotEmpty == true ? t['id'] : songId(artistName, title);
    t['artistId'] = (t['artistId'] as String?)?.isNotEmpty == true
        ? t['artistId']
        : artistId(artistName);
    final albumTitle = ((t['albumTitle'] as String?) ?? '').trim();
    t['albumTitle'] = albumTitle;
    t['albumId'] = (t['albumId'] as String?)?.isNotEmpty == true
        ? t['albumId']
        : (albumTitle.isNotEmpty ? albumId(artistName, albumTitle) : '');
    t['isPublished'] = t['isPublished'] == true;
    t['isDownloadable'] = t['isDownloadable'] != false;

    return TrackValidationResult(
      errors: errors,
      warnings: warnings,
      normalized: t,
    );
  }

  /// Duplicate detection across a batch (same id or same title+artist).
  /// Returns a map of record index → reason.
  static Map<int, String> findDuplicates(List<Map<String, dynamic>> tracks) {
    final byId = <String, int>{};
    final byKey = <String, int>{};
    final dups = <int, String>{};
    for (var i = 0; i < tracks.length; i++) {
      final t = tracks[i];
      final id = (t['id'] as String?) ?? '';
      if (id.isNotEmpty && byId.containsKey(id)) {
        dups[i] = 'duplicate id "$id" (row ${byId[id]! + 1})';
      } else if (id.isNotEmpty) {
        byId[id] = i;
      }
      final key =
          '${slugify((t['artistName'] as String?) ?? '')}|${slugify((t['title'] as String?) ?? '')}';
      if (byKey.containsKey(key)) {
        dups[i] = 'duplicate title+artist (row ${byKey[key]! + 1})';
      } else {
        byKey[key] = i;
      }
    }
    return dups;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
