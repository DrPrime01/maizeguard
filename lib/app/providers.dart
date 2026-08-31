import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/scan_dao.dart';
import '../data/local/settings_dao.dart';
import '../data/remote/firestore_scan_source.dart';
import '../data/repositories/scan_repository.dart';
import '../domain/models/scan.dart';
import '../ml/classifier.dart';
import '../ml/stub_classifier.dart';
import '../ml/tflite_classifier.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/image_store.dart';
import '../services/location_service.dart';
import '../services/sync_service.dart';

/// Flip to `true` once a trained model is dropped into
/// `assets/model/maize_mobilenetv2.tflite`.
///
/// This is the single switch between the stub used during development and the
/// real classifier — see section 10 of `ml/maize_guard_training.ipynb`.
const bool kUseTrainedModel = false;

/// Set at startup by `main()`: whether `Firebase.initializeApp()` succeeded.
/// Overridden in the root [ProviderScope], never read before that.
final firebaseAvailableProvider = Provider<bool>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

// --- infrastructure ---------------------------------------------------------

final scanDaoProvider = Provider<ScanDao>((ref) => ScanDao());
final settingsDaoProvider = Provider<SettingsDao>((ref) => SettingsDao());
final imageStoreProvider = Provider<ImageStore>((ref) => const ImageStore());
final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());
final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityService());

final scanRepositoryProvider = Provider<ScanRepository>(
  (ref) => ScanRepository(
    dao: ref.watch(scanDaoProvider),
    imageStore: ref.watch(imageStoreProvider),
  ),
);

// --- authentication ---------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) {
  return ref.watch(firebaseAvailableProvider)
      ? FirebaseAuthService()
      : LocalAuthService(ref.watch(settingsDaoProvider));
});

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

/// The signed-in user's id, or null. Every query that reads observations is
/// scoped by this, which is what keeps one user's records out of another's
/// view (AT-09) even before the Firestore rules are involved.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.id,
);

// --- machine learning -------------------------------------------------------

final classifierProvider = Provider<DiseaseClassifier>((ref) {
  final classifier =
      kUseTrainedModel ? TfliteClassifier() : StubClassifier();
  ref.onDispose(classifier.dispose);
  return classifier;
});

/// Loads the model once and hands back the ready classifier.
///
/// Kept separate from [classifierProvider] so the detect screen can show a
/// loading state and surface a load failure instead of throwing mid-capture.
final classifierReadyProvider = FutureProvider<DiseaseClassifier>((ref) async {
  final classifier = ref.watch(classifierProvider);
  await classifier.load();
  return classifier;
});

// --- settings ---------------------------------------------------------------

class ConfidenceThreshold extends AsyncNotifier<double> {
  @override
  Future<double> build() =>
      ref.read(settingsDaoProvider).readConfidenceThreshold();

  Future<void> set(double value) async {
    await ref.read(settingsDaoProvider).writeConfidenceThreshold(value);
    state = AsyncData(value);
  }
}

final confidenceThresholdProvider =
    AsyncNotifierProvider<ConfidenceThreshold, double>(ConfidenceThreshold.new);

// --- observations -----------------------------------------------------------

/// Bumped whenever an observation is written, to refresh every derived view.
/// A single counter is enough here — the queries are small and local.
class ObservationRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final observationRevisionProvider =
    NotifierProvider<ObservationRevision, int>(ObservationRevision.new);

final historyProvider = FutureProvider<List<Scan>>((ref) async {
  ref.watch(observationRevisionProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(scanRepositoryProvider).history(userId);
});

final mappableScansProvider = FutureProvider<List<Scan>>((ref) async {
  ref.watch(observationRevisionProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  return ref.watch(scanRepositoryProvider).mappable(userId);
});

final scanStatsProvider = FutureProvider<ScanStats>((ref) async {
  ref.watch(observationRevisionProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return ScanStats.empty;
  return ref.watch(scanRepositoryProvider).stats(userId);
});

// --- synchronisation --------------------------------------------------------

final firestoreScanSourceProvider =
    Provider<FirestoreScanSource>((ref) => FirestoreScanSource());

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(
    dao: ref.watch(scanDaoProvider),
    remote: ref.watch(firestoreScanSourceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).onStatusChange,
);

/// Drives the sync indicator and the manual "sync now" action.
class SyncController extends Notifier<SyncOutcome> {
  @override
  SyncOutcome build() {
    // Auto-sync only makes sense with a real cloud account behind it.
    final userId = ref.watch(currentUserIdProvider);
    final canSync = ref.watch(authServiceProvider).supportsSync;
    if (userId != null && canSync) {
      final service = ref.watch(syncServiceProvider)..startAutoSync(userId);
      ref.onDispose(service.stopAutoSync);
    }
    return SyncOutcome.idle;
  }

  bool get _enabled => ref.read(authServiceProvider).supportsSync;

  Future<void> syncNow() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || !_enabled) return;
    state = await ref.read(syncServiceProvider).syncNow(userId);
    ref.read(observationRevisionProvider.notifier).bump();
  }
}

final syncControllerProvider =
    NotifierProvider<SyncController, SyncOutcome>(SyncController.new);
