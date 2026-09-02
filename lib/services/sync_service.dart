import 'dart:async';

import '../data/local/scan_dao.dart';
import '../data/remote/firestore_scan_source.dart';
import '../domain/models/sync_status.dart';
import 'connectivity_service.dart';

/// Result of one synchronisation sweep.
class SyncOutcome {
  const SyncOutcome({
    required this.uploaded,
    required this.remaining,
    this.error,
  });

  final int uploaded;
  final int remaining;
  final Object? error;

  bool get succeeded => error == null;

  static const idle = SyncOutcome(uploaded: 0, remaining: 0);
}

/// Uploads pending observations when the device has connectivity (FR-10).
///
/// Design notes:
/// * The local database is never mutated destructively by sync — rows are only
///   flagged. Losing the network mid-sweep costs nothing.
/// * A sweep is single-flight. Connectivity flapping fires the listener
///   repeatedly, and overlapping sweeps would upload the same rows twice.
/// * Failures mark rows `failed`, not `synced`, so the next sweep retries them.
class SyncService {
  SyncService({
    ScanDao? dao,
    FirestoreScanSource? remote,
    ConnectivityService? connectivity,
  })  : _dao = dao ?? ScanDao(),
        _remote = remote ?? FirestoreScanSource(),
        _connectivity = connectivity ?? ConnectivityService();

  final ScanDao _dao;
  final FirestoreScanSource _remote;
  final ConnectivityService _connectivity;

  Future<SyncOutcome>? _inFlight;

  /// Uploads everything pending for [userId].
  ///
  /// Returns without error when offline — there is nothing wrong with being
  /// offline, it is the expected state in the field.
  Future<SyncOutcome> syncNow(String userId) {
    return _inFlight ??= _run(userId).whenComplete(() => _inFlight = null);
  }

  Future<SyncOutcome> _run(String userId) async {
    final pending = await _dao.listUnsyncedForUser(userId);
    if (pending.isEmpty) return SyncOutcome.idle;

    if (!await _connectivity.isOnline) {
      return SyncOutcome(uploaded: 0, remaining: pending.length);
    }

    try {
      await _remote.uploadBatch(pending);
      await _dao.markSynced(pending.map((s) => s.id));
      return SyncOutcome(uploaded: pending.length, remaining: 0);
    } catch (error) {
      for (final scan in pending) {
        await _dao.updateSyncStatus(scan.id, SyncStatus.failed);
      }
      return SyncOutcome(
        uploaded: 0,
        remaining: pending.length,
        error: error,
      );
    }
  }

  void dispose() {}
}
