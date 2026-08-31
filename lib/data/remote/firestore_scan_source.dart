import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/scan.dart';

/// Writes observations to Firestore under `users/{uid}/scans/{scanId}`.
///
/// The path is per-user by construction, which is what the security rules key
/// off to stop one user reading another's records (AT-09).
///
/// Metadata only: the captured image stays on the device. See the PRD decision
/// on image sync — uploading photos would require Cloud Storage, which now
/// needs a billing-enabled plan on new Firebase projects.
class FirestoreScanSource {
  FirestoreScanSource([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _scansOf(String userId) =>
      _firestore.collection('users').doc(userId).collection('scans');

  /// Uploads a batch of observations as one atomic commit.
  ///
  /// IMPORTANT: Firestore's own offline persistence means a `set()` issued
  /// with no connectivity resolves locally but its Future does not complete
  /// until the server acknowledges. Awaiting that offline hangs indefinitely.
  /// The caller only invokes this when connectivity is reported, and [timeout]
  /// is the backstop for the case where connectivity is reported but the link
  /// is actually dead (captive portals, a bar of signal that carries nothing).
  Future<void> uploadBatch(
    List<Scan> scans, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (scans.isEmpty) return;

    final batch = _firestore.batch();
    for (final scan in scans) {
      batch.set(
        _scansOf(scan.userId).doc(scan.id),
        {
          ...scan.toFirestore(),
          'syncedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit().timeout(timeout);
  }

  /// Ensures the user profile document exists (data model: Users collection).
  Future<void> upsertUserProfile({
    required String userId,
    required String email,
    String? displayName,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'userId': userId,
      'email': email,
      if (displayName != null) 'displayName': displayName,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
