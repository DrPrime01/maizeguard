import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Local SQLite store (FR-09).
///
/// This is the source of truth for the app. Firestore is a synchronisation
/// target, not a cache in front of this — every read the UI performs comes
/// from here, which is what lets history and the map work with no network.
abstract final class AppDatabase {
  static const String scansTable = 'scans';
  static const String settingsTable = 'settings';
  static const int _version = 1;

  static Database? _instance;

  static Future<Database> get instance async =>
      _instance ??= await _open();

  static Future<Database> _open() async {
    final dbPath = p.join(await getDatabasesPath(), 'maize_guard.db');
    return openDatabase(
      dbPath,
      version: _version,
      onCreate: _onCreate,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $scansTable (
        id              TEXT PRIMARY KEY,
        user_id         TEXT NOT NULL,
        image_path      TEXT NOT NULL,
        disease         TEXT NOT NULL,
        confidence      REAL NOT NULL,
        threshold_used  REAL NOT NULL,
        accepted        INTEGER NOT NULL,
        captured_at     INTEGER NOT NULL,
        inference_ms    INTEGER NOT NULL,
        latitude        REAL,
        longitude       REAL,
        accuracy_meters REAL,
        sync_status     TEXT NOT NULL
      )
    ''');

    // History is always "this user's scans, newest first".
    await db.execute(
      'CREATE INDEX idx_scans_user_captured '
      'ON $scansTable (user_id, captured_at DESC)',
    );
    // The sync sweep asks only for this user's pending rows.
    await db.execute(
      'CREATE INDEX idx_scans_sync ON $scansTable (user_id, sync_status)',
    );

    // Small key/value table for app settings (the confidence threshold).
    // Kept here rather than pulling in a separate preferences package — it is
    // one row, and it keeps all local state in a single file.
    await db.execute('''
      CREATE TABLE $settingsTable (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Test hook — lets unit tests supply an in-memory database.
  static void overrideInstance(Database db) => _instance = db;

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
