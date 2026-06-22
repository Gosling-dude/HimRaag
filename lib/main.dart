import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/local/hive_boxes.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[APP] APP_START');

  // ── Firebase ──────────────────────────────────────────────────────────────
  debugPrint('[APP] FIREBASE_INIT_START');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[APP] FIREBASE_INIT_SUCCESS');

  FlutterError.onError = (details) {
    debugPrint('[APP] FLUTTER_ERROR: ${details.exception}');
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[APP] PLATFORM_ERROR: $error');
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // ── Audio background service ───────────────────────────────────────────────
  // Wrapped in try/catch + timeout: on some physical devices the AudioService
  // foreground-service binding never resolves, which would block runApp() and
  // keep the Android launch screen visible forever.
  //
  // CRITICAL: JustAudioBackground.init() swaps the global JustAudioPlatform.
  // instance to its background plugin *synchronously*, then awaits
  // AudioService.init(). If that await hangs (the foreground-service binding
  // never resolves) our timeout aborts it — but the broken background plugin is
  // left installed with its internal `_audioHandler` never assigned. Every
  // AudioPlayer created afterwards then throws LateInitializationError on the
  // first setAudioSource(), so playback silently dies and the duration stays at
  // 00:00. To stay playable, we capture the default (plain) platform first and
  // restore it on failure — the app loses lock-screen controls but audio works.
  final JustAudioPlatform defaultAudioPlatform = JustAudioPlatform.instance;
  debugPrint('[APP] AUDIO_BG_INIT_START');
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.himraag.app.audio',
      androidNotificationChannelName: 'HimRaag Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      notificationColor: const Color(0xFF6B3FA0),
    ).timeout(const Duration(seconds: 5));
    debugPrint('[APP] AUDIO_BG_INIT_SUCCESS');
  } catch (e) {
    // Restore the plain just_audio platform so foreground playback keeps
    // working; we just lose background/lock-screen media controls.
    JustAudioPlatform.instance = defaultAudioPlatform;
    debugPrint('[APP] AUDIO_BG_INIT_FAILED — restored default platform: $e');
  }

  // ── Local storage ─────────────────────────────────────────────────────────
  debugPrint('[APP] HIVE_INIT_START');
  await Hive.initFlutter();
  await HiveBoxes.registerAdapters();
  await HiveBoxes.openBoxes();
  debugPrint('[APP] HIVE_INIT_SUCCESS');

  // ── UI setup ──────────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  debugPrint('[APP] RUN_APP');
  runApp(const ProviderScope(child: HimRaagApp()));
}

class HimRaagApp extends ConsumerWidget {
  const HimRaagApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('[APP] ROUTER_BUILD');
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
      ],
    );
  }
}
