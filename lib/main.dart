import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is optional at startup by design.
  //
  // Detection, GPS capture, local persistence and the map are all offline
  // features (PRD §11) and must not be held hostage to a backend that has not
  // been configured yet. Without `google-services.json` this throws, and the
  // app falls back to a device-local account with sync disabled.
  var firebaseAvailable = false;
  try {
    await Firebase.initializeApp();
    firebaseAvailable = true;
  } catch (error) {
    debugPrint('Firebase unavailable, running locally: $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        firebaseAvailableProvider.overrideWithValue(firebaseAvailable),
      ],
      child: const MaizeGuardApp(),
    ),
  );
}

class MaizeGuardApp extends ConsumerWidget {
  const MaizeGuardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MaizeGuard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
