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
import '../../features/browse/presentation/browse_screens.dart';
import '../../features/profile/presentation/my_requests_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

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

  // Sign-in is required: everything except the auth screens needs a real
  // (Google) account. Anonymous sessions left over from the old guest mode
  // don't count. Reads FirebaseAuth directly because currentUser is restored
  // synchronously at startup, before authStateProvider's first emission.
  String? redirect(BuildContext context, GoRouterState state) {
    final user = _ref.read(firebaseAuthProvider).currentUser;
    final signedIn = user != null && !user.isAnonymous;
    final onAuthScreen = state.matchedLocation == '/sign-in' ||
        state.matchedLocation == '/onboarding';

    if (!signedIn && !onAuthScreen) return '/sign-in';
    if (signedIn && onAuthScreen) return '/home';
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
            builder: (context, state) => LibraryScreen(
              initialTab:
                  int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
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
        path: '/profile/requests',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyRequestsScreen(),
      ),
      GoRoute(
        path: '/browse/trending',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TrendingScreen(),
      ),
      GoRoute(
        path: '/browse/new-releases',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NewReleasesScreen(),
      ),
      GoRoute(
        path: '/browse/for-you',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RecommendedScreen(),
      ),
      GoRoute(
        path: '/albums',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AlbumsScreen(),
      ),
      GoRoute(
        path: '/artists',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ArtistsScreen(),
      ),
      GoRoute(
        path: '/festival/:name',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            FestivalScreen(festival: state.pathParameters['name']!),
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
