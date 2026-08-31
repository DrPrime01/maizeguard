import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/detect/detect_screen.dart';
import '../features/disease/disease_detail_screen.dart';
import '../features/disease/disease_list_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/home/shell_scaffold.dart';
import '../features/map/map_screen.dart';
import '../features/settings/settings_screen.dart';
import '../domain/models/disease_class.dart';
import 'providers.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/';
  static const map = '/map';
  static const history = '/history';
  static const diseases = '/diseases';
  static const detect = '/detect';
  static const settings = '/settings';
}

/// Bridges the auth stream to something GoRouter can listen to.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final location = state.matchedLocation;

      // Hold on the splash until the first auth event arrives, so we never
      // flash the login screen at an already-signed-in user.
      if (auth.isLoading) {
        return location == Routes.splash ? null : Routes.splash;
      }

      final signedIn = auth.value != null;
      if (!signedIn) {
        return location == Routes.login ? null : Routes.login;
      }
      if (location == Routes.login || location == Routes.splash) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.detect,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const DetectScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: _rootKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/diseases/:id',
        parentNavigatorKey: _rootKey,
        builder: (context, state) => DiseaseDetailScreen(
          diseaseClass: DiseaseClass.fromId(state.pathParameters['id']!),
        ),
      ),
      // The four primary destinations keep their own navigation stacks.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.map,
              builder: (context, state) => const MapScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.history,
              builder: (context, state) => const HistoryScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.diseases,
              builder: (context, state) => const DiseaseListScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
