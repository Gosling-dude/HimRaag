import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../domain/models/app_user.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/player/presentation/screens/full_player_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/songs/presentation/screens/album_detail_screen.dart';
import '../../features/songs/presentation/screens/artist_detail_screen.dart';
import '../../features/songs/presentation/screens/category_screen.dart';
import '../../features/songs/presentation/screens/playlist_detail_screen.dart';
import '../../features/songs/presentation/screens/region_screen.dart';
import '../shell/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// Notifier that GoRouter listens to for auth changes.
// Using refreshListenable keeps the GoRouter as a singleton — no GlobalKey
// conflicts from recreating the router on every auth state emission.
class _RouterNotifier extends ChangeNotifier {
  _RouterNotifier(this._ref) {
    _ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (_, next) {
        debugPrint('[APP] AUTH_STATE_CHANGED: ${next.runtimeType}');
        notifyListeners();
      },
    );
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    // Guest mode: no forced sign-in. All routes are reachable anonymously.
    // Add redirect logic here when sign-in becomes required.
    return null;
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  debugPrint('[APP] ROUTER_INIT');
  final notifier = _RouterNotifier(ref);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) {
              debugPrint('[APP] HOME_SCREEN_RENDER');
              return const HomeScreen();
            },
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/library',
            builder: (context, state) => const LibraryScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const FullPlayerScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/album/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            AlbumDetailScreen(albumId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/artist/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ArtistDetailScreen(artistId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/category/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            CategoryScreen(categoryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/region/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            RegionScreen(regionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/playlist/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PlaylistDetailScreen(playlistId: state.pathParameters['id']!),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.error}'),
      ),
    ),
  );

  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});
