import 'package:sqflite/sqflite.dart';

import '../../core/app_config.dart';
import 'database.dart';

/// Reads and writes the handful of user-adjustable settings.
class SettingsDao {
  SettingsDao([Database? db]) : _override = db;

  final Database? _override;

  Future<Database> get _db async => _override ?? await AppDatabase.instance;

  Future<double> readConfidenceThreshold() async {
    final raw = await _read(AppConfig.keyConfidenceThreshold);
    final parsed = raw == null ? null : double.tryParse(raw);
    if (parsed == null) return AppConfig.defaultConfidenceThreshold;
    return parsed.clamp(
      AppConfig.minConfidenceThreshold,
      AppConfig.maxConfidenceThreshold,
    );
  }

  Future<void> writeConfidenceThreshold(double value) => _write(
        AppConfig.keyConfidenceThreshold,
        value
            .clamp(
              AppConfig.minConfidenceThreshold,
              AppConfig.maxConfidenceThreshold,
            )
            .toString(),
      );

  /// Generic accessors used by the local (non-Firebase) account fallback.
  Future<String?> readString(String key) => _read(key);

  Future<void> writeString(String key, String value) => _write(key, value);

  Future<String?> _read(String key) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.settingsTable,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> _write(String key, String value) async {
    final db = await _db;
    await db.insert(
      AppDatabase.settingsTable,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
