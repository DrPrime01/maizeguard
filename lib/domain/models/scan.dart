import 'disease_class.dart';
import 'sync_status.dart';

/// One field observation: a captured leaf image, what the model made of it,
/// and where and when it was taken.
///
/// Covers FR-08 (image, class, confidence, timestamp, location) plus the
/// bookkeeping needed for offline sync (FR-09/FR-10) and the performance
/// measurement required by AT-10.
class Scan {
  const Scan({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.disease,
    required this.confidence,
    required this.thresholdUsed,
    required this.accepted,
    required this.capturedAt,
    required this.inferenceMs,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.syncStatus = SyncStatus.pending,
  });

  /// Client-generated UUID. Doubles as the Firestore document id so an
  /// interrupted sync that retries cannot create a duplicate record.
  final String id;
  final String userId;

  /// Absolute path to the captured image in the app documents directory.
  /// Device-local by design — images are not uploaded (metadata-only sync).
  final String imagePath;

  final DiseaseClass disease;

  /// Top-1 probability, 0.0–1.0.
  final double confidence;

  /// The threshold in force when this scan was taken. Stored per-record so a
  /// later change to the setting cannot retroactively reinterpret history.
  final double thresholdUsed;

  /// False when confidence fell below [thresholdUsed] — the observation is
  /// retained but flagged as unconfirmed rather than silently trusted (FR-06).
  final bool accepted;

  final DateTime capturedAt;

  /// Wall-clock inference time in milliseconds (AT-10).
  final int inferenceMs;

  /// Null when GPS was unavailable or permission was denied (AT-04).
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;

  final SyncStatus syncStatus;

  bool get hasLocation => latitude != null && longitude != null;

  Scan copyWith({
    String? userId,
    DiseaseClass? disease,
    double? confidence,
    bool? accepted,
    double? latitude,
    double? longitude,
    double? accuracyMeters,
    SyncStatus? syncStatus,
  }) {
    return Scan(
      id: id,
      userId: userId ?? this.userId,
      imagePath: imagePath,
      disease: disease ?? this.disease,
      confidence: confidence ?? this.confidence,
      thresholdUsed: thresholdUsed,
      accepted: accepted ?? this.accepted,
      capturedAt: capturedAt,
      inferenceMs: inferenceMs,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyMeters: accuracyMeters ?? this.accuracyMeters,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'image_path': imagePath,
        'disease': disease.id,
        'confidence': confidence,
        'threshold_used': thresholdUsed,
        'accepted': accepted ? 1 : 0,
        'captured_at': capturedAt.toUtc().millisecondsSinceEpoch,
        'inference_ms': inferenceMs,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
        'sync_status': syncStatus.id,
      };

  factory Scan.fromMap(Map<String, Object?> map) => Scan(
        id: map['id']! as String,
        userId: map['user_id']! as String,
        imagePath: map['image_path']! as String,
        disease: DiseaseClass.fromId(map['disease']! as String),
        confidence: (map['confidence']! as num).toDouble(),
        thresholdUsed: (map['threshold_used']! as num).toDouble(),
        accepted: (map['accepted']! as num) == 1,
        capturedAt: DateTime.fromMillisecondsSinceEpoch(
          map['captured_at']! as int,
          isUtc: true,
        ).toLocal(),
        inferenceMs: (map['inference_ms'] as num?)?.toInt() ?? 0,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        accuracyMeters: (map['accuracy_meters'] as num?)?.toDouble(),
        syncStatus: SyncStatus.fromId(map['sync_status'] as String?),
      );

  /// Firestore payload. Deliberately excludes [imagePath] — it is a local
  /// filesystem path with no meaning on another device, and the image itself
  /// is not uploaded.
  Map<String, Object?> toFirestore() => {
        'scanId': id,
        'userId': userId,
        'disease': disease.id,
        'confidence': confidence,
        'thresholdUsed': thresholdUsed,
        'accepted': accepted,
        'capturedAt': capturedAt.toUtc().toIso8601String(),
        'inferenceMs': inferenceMs,
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
      };
}
