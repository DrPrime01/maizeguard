/// Tracks whether a locally-stored observation has reached Firestore.
///
/// Records are never deleted locally once synced — the local database stays
/// the source of truth for history and the map so both work fully offline.
enum SyncStatus {
  /// Saved on device, not yet uploaded.
  pending('pending'),

  /// Confirmed written to Firestore.
  synced('synced'),

  /// Upload attempted and rejected; eligible for retry.
  failed('failed');

  const SyncStatus(this.id);

  final String id;

  static SyncStatus fromId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return SyncStatus.pending;
  }
}
