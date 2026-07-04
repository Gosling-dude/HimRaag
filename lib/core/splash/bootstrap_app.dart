import 'package:flutter/material.dart';

/// Branded launch experience. [runApp] is called with this widget immediately
/// so the splash artwork is on screen while Firebase / Hive / the audio
/// service initialize behind it (previously all of that blocked runApp and the
/// user stared at the bare Android launch screen).
///
/// Rules:
///  - splash stays up for at least [_minSplashDuration] to avoid a flicker
///    when initialization is fast;
///  - if initialization takes longer, the splash simply stays until it's done;
///  - the real app is built *underneath* the splash and revealed with a fade,
///    so there is never a blank frame or white flash between the two.
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({
    super.key,
    required this.initialization,
    required this.appBuilder,
  });

  /// Future started in main() that performs all pre-app initialization.
  final Future<void> initialization;

  /// Builds the real application (ProviderScope + MaterialApp.router). Only
  /// invoked once initialization has finished.
  final WidgetBuilder appBuilder;

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  static const _minSplashDuration = Duration(milliseconds: 1600);
  static const _fadeDuration = Duration(milliseconds: 650);

  /// Matches the deep navy of the splash artwork and the native launch
  /// screen background (#0D0D14) closely enough that transitions are seamless.
  static const _splashBackground = Color(0xFF0D0D14);

  bool _appReady = false;
  bool _splashDismissed = false;

  @override
  void initState() {
    super.initState();
    _awaitInitialization();
  }

  Future<void> _awaitInitialization() async {
    await Future.wait<void>([
      // Initialization failures are logged inside _initialize(); never let
      // them keep the splash on screen forever.
      widget.initialization.catchError((Object e, StackTrace st) {
        debugPrint('[APP] BOOTSTRAP_INIT_ERROR: $e\n$st');
      }),
      Future<void>.delayed(_minSplashDuration),
    ]);
    if (mounted) setState(() => _appReady = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        // Opaque backstop so nothing transparent is ever visible.
        const ColoredBox(color: _splashBackground, child: SizedBox.expand()),
        if (_appReady) widget.appBuilder(context),
        if (!_splashDismissed)
          IgnorePointer(
            ignoring: _appReady,
            child: AnimatedOpacity(
              opacity: _appReady ? 0.0 : 1.0,
              duration: _fadeDuration,
              curve: Curves.easeOut,
              onEnd: () {
                if (_appReady && mounted) {
                  setState(() => _splashDismissed = true);
                }
              },
              child: const _SplashArtwork(background: _splashBackground),
            ),
          ),
      ],
    );
  }
}

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: background,
        child: SizedBox.expand(
          child: Image.asset(
            'assets/images/opening_page.png',
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Fade the artwork in over the dark background on the very first
            // frames while the PNG decodes — reads as intentional, never as a
            // flash.
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeIn,
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}
