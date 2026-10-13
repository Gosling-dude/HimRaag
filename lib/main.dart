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
import 'data/services/play_tracking.dart';
import 'features/profile/settings_providers.dart';
import 'features/recommendations/recommendation_providers.dart';
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
  // Powers the media notification + lock-screen controls. Requires MainActivity
  // to extend AudioServiceActivity — with a plain FlutterActivity the binding
  // below never resolves. Still wrapped in try/catch + timeout as a safety net
  // so a failure can't block runApp() and freeze the launch screen.
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
      androidNotificationIcon: 'drawable/ic_stat_music',
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

class HimRaagApp extends ConsumerStatefulWidget {
  const HimRaagApp({super.key});

  @override
  ConsumerState<HimRaagApp> createState() => _HimRaagAppState();
}

class _HimRaagAppState extends ConsumerState<HimRaagApp> {
  // Send buffered plays when the app leaves the foreground — the last chance
  // before Android may kill the process.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: () => ref.read(playReporterProvider).flush(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // initialise the late listener
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[APP] ROUTER_BUILD');
    ref.watch(playTrackingProvider);
    ref.watch(autoplayProvider);
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
