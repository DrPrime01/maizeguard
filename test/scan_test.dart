import 'package:flutter_test/flutter_test.dart';
import 'package:maize_guard/domain/models/disease_class.dart';
import 'package:maize_guard/domain/models/scan.dart';
import 'package:maize_guard/domain/models/sync_status.dart';

Scan buildScan({
  double? latitude,
  double? longitude,
  SyncStatus syncStatus = SyncStatus.pending,
  bool accepted = true,
}) {
  return Scan(
    id: 'scan-1',
    userId: 'user-1',
    imagePath: '/data/app/scan_images/scan-1.jpg',
    disease: DiseaseClass.greyLeafSpot,
    confidence: 0.8123,
    thresholdUsed: 0.70,
    accepted: accepted,
    capturedAt: DateTime.fromMillisecondsSinceEpoch(1735689600000),
    inferenceMs: 63,
    latitude: latitude,
    longitude: longitude,
    accuracyMeters: latitude == null ? null : 8.5,
    syncStatus: syncStatus,
  );
}

void main() {
  group('Scan persistence round-trip', () {
    test('survives toMap/fromMap unchanged', () {
      final original = buildScan(latitude: 7.3775, longitude: 3.9470);
      final restored = Scan.fromMap(original.toMap());

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.disease, original.disease);
      expect(restored.confidence, closeTo(original.confidence, 1e-9));
      expect(restored.thresholdUsed, closeTo(original.thresholdUsed, 1e-9));
      expect(restored.accepted, original.accepted);
      expect(restored.inferenceMs, original.inferenceMs);
      expect(restored.latitude, closeTo(7.3775, 1e-9));
      expect(restored.longitude, closeTo(3.9470, 1e-9));
      expect(restored.syncStatus, SyncStatus.pending);
      expect(
        restored.capturedAt.millisecondsSinceEpoch,
        original.capturedAt.millisecondsSinceEpoch,
      );
    });

    test('AT-04: an observation with no GPS fix is still a valid record', () {
      final scan = buildScan();
      expect(scan.hasLocation, isFalse);

      final restored = Scan.fromMap(scan.toMap());
      expect(restored.latitude, isNull);
      expect(restored.longitude, isNull);
      expect(restored.hasLocation, isFalse);
    });

    test('an unconfirmed low-confidence scan keeps its accepted=false flag',
        () {
      final scan = buildScan(accepted: false);
      expect(Scan.fromMap(scan.toMap()).accepted, isFalse);
    });
  });

  group('Firestore payload', () {
    test('never carries the device-local image path', () {
      final payload = buildScan(latitude: 7.0, longitude: 3.0).toFirestore();
      expect(payload.containsKey('imagePath'), isFalse);
      expect(payload.values.any((v) => v.toString().contains('scan_images')),
          isFalse);
    });

    test('carries the fields the security rules validate', () {
      final payload = buildScan(latitude: 7.0, longitude: 3.0).toFirestore();
      expect(payload['scanId'], 'scan-1');
      expect(payload['userId'], 'user-1');
      expect(payload['disease'], 'grey_leaf_spot');
      expect(payload['confidence'], isA<double>());
      expect(payload['accepted'], isA<bool>());
      expect(payload['capturedAt'], isA<String>());
    });
  });

  group('SyncStatus', () {
    test('unknown or missing values fall back to pending, never to synced', () {
      // A record must never be assumed uploaded just because its status was
      // unreadable — that would silently lose field data.
      expect(SyncStatus.fromId(null), SyncStatus.pending);
      expect(SyncStatus.fromId('nonsense'), SyncStatus.pending);
      expect(SyncStatus.fromId('synced'), SyncStatus.synced);
    });
  });
}
