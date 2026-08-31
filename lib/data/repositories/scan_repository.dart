import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../domain/models/disease_class.dart';
import '../../domain/models/scan.dart';
import '../../domain/models/sync_status.dart';
import '../../ml/prediction.dart';
import '../../services/image_store.dart';
import '../../services/location_service.dart';
import '../local/scan_dao.dart';

/// Single entry point for creating and reading observations.
///
/// Persisting locally is unconditional and happens before any thought of
/// upload — that ordering is the whole reliability requirement (FR-09: an
/// observation must never be lost because the network was absent).
class ScanRepository {
  ScanRepository({
    ScanDao? dao,
    ImageStore? imageStore,
    Uuid? uuid,
  })  : _dao = dao ?? ScanDao(),
        _imageStore = imageStore ?? const ImageStore(),
        _uuid = uuid ?? const Uuid();

  final ScanDao _dao;
  final ImageStore _imageStore;
  final Uuid _uuid;

  /// Persists a completed detection (FR-08).
  ///
  /// [location] is whatever the GPS attempt produced; anything other than a
  /// fix stores the observation without coordinates rather than discarding it.
  Future<Scan> saveObservation({
    required String userId,
    required File capturedImage,
    required Prediction prediction,
    required double threshold,
    required LocationResult location,
  }) async {
    final id = _uuid.v4();
    final stored = await _imageStore.persist(capturedImage, id);

    final fix = location is LocationFix ? location : null;
    final scan = Scan(
      id: id,
      userId: userId,
      imagePath: stored.path,
      disease: prediction.label,
      confidence: prediction.confidence,
      thresholdUsed: threshold,
      accepted: prediction.isAcceptedAt(threshold),
      capturedAt: DateTime.now(),
      inferenceMs: prediction.inferenceMs,
      latitude: fix?.latitude,
      longitude: fix?.longitude,
      accuracyMeters: fix?.accuracyMeters,
      syncStatus: SyncStatus.pending,
    );

    await _dao.insert(scan);
    return scan;
  }

  Future<List<Scan>> history(String userId, {int? limit}) =>
      _dao.listForUser(userId, limit: limit);

  Future<List<Scan>> mappable(String userId) => _dao.listMappableForUser(userId);

  Future<ScanStats> stats(String userId) => _dao.statsForUser(userId);

  Future<Scan?> byId(String id) => _dao.findById(id);

  /// Removes an observation and its image.
  Future<void> delete(Scan scan) async {
    await _imageStore.deleteFor(scan.imagePath);
    await _dao.delete(scan.id);
  }

  /// History filtered to one disease — used by the map legend and the history
  /// filter chips.
  Future<List<Scan>> byDisease(String userId, DiseaseClass disease) async {
    final all = await _dao.listForUser(userId);
    return all.where((s) => s.disease == disease).toList();
  }
}
