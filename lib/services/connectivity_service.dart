import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus.
///
/// Note this reports *network interface* availability, not reachability — a
/// connected Wi-Fi network with no working uplink still reports connected.
/// That is why every upload path also carries a timeout.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> get isOnline async =>
      _isOnline(await _connectivity.checkConnectivity());

  /// Emits the current status immediately, then true when the device gains a
  /// network interface and false when it loses every one.
  ///
  /// The initial emission matters: `onConnectivityChanged` only fires on a
  /// *change*, so a listener that subscribes while already offline would
  /// otherwise sit with no value at all and the UI would show nothing.
  Stream<bool> get onStatusChange async* {
    yield await isOnline;
    yield* _connectivity.onConnectivityChanged.map(_isOnline);
  }
}
