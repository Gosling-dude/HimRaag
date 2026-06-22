import 'package:flutter/foundation.dart';

/// Build-time configuration for the consumer app.
///
/// The catalog contains demo-only placeholder tracks (`license == 'DEMO_ONLY'`)
/// used for internal testing. Those must never reach a public release. The
/// public visibility gate going forward is `isPublished == true`; demo content
/// is always `isPublished == false`.
///
/// [includeDemoContent] controls whether the repository layer keeps or drops
/// demo entries:
///   * Debug builds: included by default (so the team can test on the seed).
///   * Release builds: excluded by default.
///
/// Override explicitly at build time, e.g.:
///   flutter run  --dart-define=HIMRAAG_INTERNAL=true
///   flutter build apk --release --dart-define=HIMRAAG_INTERNAL=false
class AppConfig {
  AppConfig._();

  static const String _internalFlag =
      String.fromEnvironment('HIMRAAG_INTERNAL', defaultValue: 'unset');

  /// Whether demo-only catalog content is surfaced to the consumer app.
  static bool get includeDemoContent {
    switch (_internalFlag) {
      case 'true':
        return true;
      case 'false':
        return false;
      default:
        // Unset → follow build mode: demo in debug, hidden in release.
        return kDebugMode;
    }
  }
}
