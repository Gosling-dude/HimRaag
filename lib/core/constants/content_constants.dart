/// Canonical content taxonomy for the HimRaag catalog.
///
/// These values are the single source of truth for licensing, approval state,
/// and the languages we accept. The bulk-import pipeline (Node) mirrors this
/// file in `scripts/lib/constants.js` — keep the two in sync when editing.
///
/// Regions and genres live in [AppConstants] (`pahadiRegions`, `pahadiGenres`)
/// and are reused here rather than duplicated.
library;

/// How a track/album/artist asset is licensed for use in the app.
///
/// Anything that is not explicitly cleared must never be published. The public
/// gate is `isPublished == true`; demo content stays `false`.
enum LicenseType {
  /// Placeholder content for internal testing only. Never published publicly.
  demoOnly('DEMO_ONLY', cleared: false, requiresAttribution: false),

  /// Public domain — free to use, attribution optional.
  publicDomain('PUBLIC_DOMAIN', cleared: true, requiresAttribution: false),

  /// Creative Commons Zero — no rights reserved.
  cc0('CC0', cleared: true, requiresAttribution: false),

  /// Creative Commons Attribution — usable commercially with attribution.
  ccBy('CC-BY', cleared: true, requiresAttribution: true),

  /// Creative Commons Attribution-ShareAlike.
  ccBySa('CC-BY-SA', cleared: true, requiresAttribution: true),

  /// Files supplied directly by the app owner.
  provided('PROVIDED', cleared: true, requiresAttribution: false),

  /// Explicit written permission granted by artist/studio.
  permissionGranted('PERMISSION_GRANTED', cleared: true, requiresAttribution: true),

  /// Commercially licensed catalog content.
  licensed('LICENSED', cleared: true, requiresAttribution: false);

  const LicenseType(
    this.wire, {
    required this.cleared,
    required this.requiresAttribution,
  });

  /// The string persisted in Firestore.
  final String wire;

  /// Whether rights are cleared for use (everything except [demoOnly]).
  final bool cleared;

  /// Whether an exact attribution string is mandatory for this license.
  final bool requiresAttribution;

  static LicenseType fromWire(String? value) {
    return LicenseType.values.firstWhere(
      (l) => l.wire == value,
      orElse: () => LicenseType.demoOnly,
    );
  }

  static const Set<String> wires = {
    'DEMO_ONLY',
    'PUBLIC_DOMAIN',
    'CC0',
    'CC-BY',
    'CC-BY-SA',
    'PROVIDED',
    'PERMISSION_GRANTED',
    'LICENSED',
  };
}

/// Moderation state for a catalog item.
enum ApprovalStatus {
  /// Demo/placeholder content — testable internally, never public.
  demo('demo'),

  /// Submitted, awaiting moderator review.
  pending('pending'),

  /// Approved by a moderator.
  approved('approved'),

  /// Rejected by a moderator.
  rejected('rejected');

  const ApprovalStatus(this.wire);

  final String wire;

  /// The only state that is publicly visible (combined with `isPublished`).
  bool get isApproved => this == ApprovalStatus.approved;

  static ApprovalStatus fromWire(String? value) {
    return ApprovalStatus.values.firstWhere(
      (s) => s.wire == value,
      orElse: () => ApprovalStatus.pending,
    );
  }
}

class ContentConstants {
  ContentConstants._();

  /// Languages we accept for catalog content. Mirrors the Pahadi regions plus
  /// the umbrella "Pahadi" label used for cross-region compilations.
  static const List<String> languages = [
    'Garhwali',
    'Kumaoni',
    'Jaunsari',
    'Himachali',
    'Kinnauri',
    'Sirmauri',
    'Pahadi',
  ];

  /// The four regions every catalog must cover (task requirement). Validation
  /// treats a missing region/language as a hard error.
  static const List<String> mandatoryRegions = [
    'Garhwali',
    'Kumaoni',
    'Jaunsari',
    'Himachali',
  ];

  /// Firestore collections introduced by the content system.
  static const String submissionsCollection = 'submissions';
  static const String auditLogsCollection = 'auditLogs';
}
