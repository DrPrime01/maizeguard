import 'package:sqflite/sqflite.dart';

import '../../domain/models/disease_class.dart';
import '../../domain/models/scan.dart';
import '../../domain/models/sync_status.dart';
import 'database.dart';

/// Aggregate figures for the dashboard and the performance readout (AT-10).
class ScanStats {
  const ScanStats({
    required this.total,
    required this.pending,
    required this.averageInferenceMs,
    required this.countByDisease,
  });

  final int total;
  final int pending;

  /// Mean on-device inference time across all stored scans.
  final double averageInferenceMs;
  final Map<DiseaseClass, int> countByDisease;

  static const empty = ScanStats(
    total: 0,
    pending: 0,
    averageInferenceMs: 0,
    countByDisease: {},
  );
}

class ScanDao {
  ScanDao([Database? db]) : _override = db;

  final Database? _override;

  Future<Database> get _db async => _override ?? await AppDatabase.instance;

  Future<void> insert(Scan scan) async {
    final db = await _db;
    await db.insert(
      AppDatabase.scansTable,
      scan.toMap(),
      // A retried save must not create a second row for the same scan id.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Scan>> listForUser(String userId, {int? limit}) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.scansTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'captured_at DESC',
      limit: limit,
    );
    return rows.map(Scan.fromMap).toList();
  }

  /// Only scans that carry coordinates can be drawn on the map (FR-11).
  Future<List<Scan>> listMappableForUser(String userId) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.scansTable,
      where: 'user_id = ? AND latitude IS NOT NULL AND longitude IS NOT NULL',
      whereArgs: [userId],
      orderBy: 'captured_at DESC',
    );
    return rows.map(Scan.fromMap).toList();
  }

  /// The upload queue: anything not yet confirmed in Firestore (FR-10).
  Future<List<Scan>> listUnsyncedForUser(String userId) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.scansTable,
      where: 'user_id = ? AND sync_status != ?',
      whereArgs: [userId, SyncStatus.synced.id],
      orderBy: 'captured_at ASC',
    );
    return rows.map(Scan.fromMap).toList();
  }

  Future<Scan?> findById(String id) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.scansTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Scan.fromMap(rows.first);
  }

  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    final db = await _db;
    await db.update(
      AppDatabase.scansTable,
      {'sync_status': status.id},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    for (final id in ids) {
      batch.update(
        AppDatabase.scansTable,
        {'sync_status': SyncStatus.synced.id},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> delete(String id) async {
    final db = await _db;
    await db.delete(AppDatabase.scansTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<ScanStats> statsForUser(String userId) async {
    final db = await _db;

    final totals = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total,
             AVG(inference_ms) AS avg_ms,
             SUM(CASE WHEN sync_status != ? THEN 1 ELSE 0 END) AS pending
      FROM ${AppDatabase.scansTable}
      WHERE user_id = ?
      ''',
      [SyncStatus.synced.id, userId],
    );

    final byDisease = await db.rawQuery(
      '''
      SELECT disease, COUNT(*) AS count
      FROM ${AppDatabase.scansTable}
      WHERE user_id = ?
      GROUP BY disease
      ''',
      [userId],
    );

    final row = totals.first;
    return ScanStats(
      total: (row['total'] as num?)?.toInt() ?? 0,
      pending: (row['pending'] as num?)?.toInt() ?? 0,
      averageInferenceMs: (row['avg_ms'] as num?)?.toDouble() ?? 0,
      countByDisease: {
        for (final r in byDisease)
          if (DiseaseClass.tryFromId(r['disease'] as String?)
              case final DiseaseClass d)
            d: (r['count'] as num).toInt(),
      },
    );
  }
}
