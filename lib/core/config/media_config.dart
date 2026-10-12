/// Where media (audio + artwork) is served from.
///
/// The catalog stores absolute URLs that point at the bucket's
/// `pub-….r2.dev` address. Cloudflare rate-limits r2.dev and does not support
/// it for production traffic, so release builds should set the custom CDN
/// domain (the `backend/cdn-worker` Worker) at build time:
///
///   flutter build appbundle --release \
///     --dart-define=MEDIA_CDN_BASE=https://cdn.himraag.in
///
/// When set, any URL on a [legacyMediaHosts] host is rewritten to the CDN base
/// (same path), and audio requests carry a Firebase ID token so the Worker can
/// refuse anonymous hotlinking. When unset, URLs are used exactly as stored.
class MediaConfig {
  const MediaConfig({
    required this.cdnBase,
    this.legacyHostSuffixes = const ['.r2.dev'],
    this.protectedPathPrefixes = const ['/audio/'],
  });

  /// Build-time configuration for the app.
  static const MediaConfig current = MediaConfig(
    cdnBase: String.fromEnvironment('MEDIA_CDN_BASE'),
  );

  /// e.g. `https://cdn.himraag.in` (no trailing slash). Empty = disabled.
  final String cdnBase;

  /// Host suffixes that are rewritten to [cdnBase].
  final List<String> legacyHostSuffixes;

  /// Paths on the CDN that require a token (must match the Worker's
  /// PROTECTED_PREFIXES).
  final List<String> protectedPathPrefixes;

  bool get hasCdn => cdnBase.isNotEmpty;

  Uri? get cdnUri => hasCdn ? Uri.tryParse(cdnBase) : null;
}
