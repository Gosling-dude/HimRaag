import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/media_config.dart';

/// Rewrites stored media URLs onto the CDN domain and, for protected audio,
/// appends the viewer's Firebase ID token.
class MediaUrlResolver {
  const MediaUrlResolver(this._config);

  static const MediaUrlResolver current = MediaUrlResolver(MediaConfig.current);

  final MediaConfig _config;

  /// Same URL with a legacy host (r2.dev) swapped for the CDN base. Anything
  /// else — other hosts, empty strings, local paths — is returned unchanged.
  String resolve(String url) {
    final cdn = _config.cdnUri;
    if (cdn == null || url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return url;
    final host = uri.host.toLowerCase();
    if (!_config.legacyHostSuffixes.any(host.endsWith)) return url;
    return uri
        .replace(scheme: cdn.scheme, host: cdn.host, port: cdn.hasPort ? cdn.port : null)
        .toString();
  }

  /// Whether [uri] is a CDN path that the Worker protects.
  bool needsToken(Uri uri) {
    final cdn = _config.cdnUri;
    if (cdn == null || uri.host.toLowerCase() != cdn.host.toLowerCase()) {
      return false;
    }
    return _config.protectedPathPrefixes.any(uri.path.startsWith);
  }

  /// [url] resolved, plus `t=<token>` when the CDN requires it and a token is
  /// available. Without a token the URL is still returned — the Worker
  /// decides whether to serve it (REQUIRE_AUTH).
  Uri authorize(String url, String? token) {
    final uri = Uri.parse(resolve(url));
    if (token == null || token.isEmpty || !needsToken(uri)) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, 't': token});
  }
}

/// Supplies the Firebase ID token sent with protected audio requests.
typedef MediaTokenProvider = Future<String?> Function();

/// The signed-in (Google) user, or null. Sign-in is mandatory — the router
/// keeps signed-out users on /sign-in — so this never creates an anonymous
/// account; leftover anonymous sessions from the old guest mode are ignored.
User? signedInUser(FirebaseAuth auth) {
  final user = auth.currentUser;
  return user == null || user.isAnonymous ? null : user;
}

/// Only reaches Firebase when the CDN is configured — dev builds that play
/// straight from r2.dev don't need a token.
Future<String?> firebaseMediaToken() async {
  if (!MediaConfig.current.hasCdn) return null;
  try {
    final user = signedInUser(FirebaseAuth.instance);
    // Cached by the SDK; refreshed automatically when within 5 min of expiry.
    return await user?.getIdToken();
  } catch (e) {
    debugPrint('[AUTH] media token unavailable: $e');
    return null;
  }
}

final mediaUrlResolverProvider =
    Provider<MediaUrlResolver>((ref) => MediaUrlResolver.current);

final mediaTokenProvider =
    Provider<MediaTokenProvider>((ref) => firebaseMediaToken);
