import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

const schemaVersion = 1;

const _schema = [
  'CREATE TABLE categories(name TEXT PRIMARY KEY, sort INTEGER NOT NULL)',
  'CREATE TABLE facilities(id TEXT PRIMARY KEY, name TEXT NOT NULL, province TEXT, district TEXT, reviewed_at TEXT)',
  "CREATE TABLE services(id TEXT PRIMARY KEY, facility_id TEXT NOT NULL REFERENCES facilities(id), category TEXT NOT NULL, eligibility TEXT, availability TEXT, status TEXT NOT NULL CHECK(status IN ('draft','pending','verified','unavailable')))",
  'CREATE TABLE users(id TEXT PRIMARY KEY, name TEXT NOT NULL, role TEXT NOT NULL, facility_id TEXT, subject_code TEXT)',
  "CREATE TABLE referrals(seq INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT UNIQUE, subject_code TEXT NOT NULL, service_id TEXT NOT NULL REFERENCES services(id), facility_id TEXT NOT NULL, category TEXT NOT NULL, status TEXT NOT NULL, note TEXT, contact_pref TEXT NOT NULL DEFAULT 'self', created_by TEXT NOT NULL REFERENCES users(id), idem_key TEXT UNIQUE, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)",
  'CREATE TABLE followups(id INTEGER PRIMARY KEY AUTOINCREMENT, referral_id TEXT NOT NULL REFERENCES referrals(id), owner_id TEXT NOT NULL, due_at TEXT NOT NULL, outcome TEXT, completed_at TEXT)',
  'CREATE TABLE audit(id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT NOT NULL, actor TEXT NOT NULL, action TEXT NOT NULL, resource TEXT NOT NULL, outcome TEXT NOT NULL, detail TEXT)',
  'CREATE INDEX idx_ref_facility ON referrals(facility_id)',
  'CREATE INDEX idx_ref_subject ON referrals(subject_code)',
  'CREATE INDEX idx_audit_resource ON audit(resource)',
];

const _tables = ['audit', 'followups', 'referrals', 'users', 'services', 'facilities', 'categories'];

/// Owns the SQLite connection, schema creation, backup and restore.
class AppDb {
  AppDb._(this.path, this._db);
  final String path;
  Database _db;
  Database get db => _db;

  static AppDb open(String path) {
    final d = sqlite3.open(path);
    d.execute('PRAGMA foreign_keys=ON');
    final a = AppDb._(path, d);
    a._ensureSchema();
    return a;
  }

  static AppDb inMemory() {
    final d = sqlite3.openInMemory();
    d.execute('PRAGMA foreign_keys=ON');
    final a = AppDb._(':memory:', d);
    a._ensureSchema();
    return a;
  }

  void _ensureSchema() {
    final v = _db.select('PRAGMA user_version').first['user_version'] as int;
    if (v == 0) {
      _db.execute('BEGIN');
      try {
        createSchema();
        _db.execute('COMMIT');
      } catch (_) {
        _db.execute('ROLLBACK');
        rethrow;
      }
    } else if (v > schemaVersion) {
      throw StateError('This data file was created by a newer version of the app.');
    }
    // Future migrations: add `if (v < 2) {...}` blocks here and bump schemaVersion.
  }

  /// Drops and recreates every table. Callers provide the surrounding transaction.
  void createSchema() {
    for (final t in _tables) {
      _db.execute('DROP TABLE IF EXISTS $t');
    }
    for (final s in _schema) {
      _db.execute(s);
    }
    _db.execute('PRAGMA user_version=$schemaVersion');
  }

  bool get isEmpty => _db.select('SELECT COUNT(*) n FROM users').first['n'] == 0;

  /// Writes a consistent copy of the database to [target].
  void backupTo(String target) {
    final f = File(target);
    if (f.existsSync()) f.deleteSync();
    _db.execute('VACUUM INTO ?', [target]);
  }

  /// Replaces the live database with the backup at [source] after validating it.
  void restoreFrom(String source) {
    final probe = sqlite3.open(source, mode: OpenMode.readOnly);
    try {
      final v = probe.select('PRAGMA user_version').first['user_version'] as int;
      final n = probe.select("SELECT COUNT(*) n FROM sqlite_master WHERE name IN ('referrals','services','audit')").first['n'] as int;
      if (v == 0 || v > schemaVersion || n != 3) {
        throw StateError('That file is not a YouthCare Connect backup.');
      }
    } finally {
      probe.dispose();
    }
    if (path == ':memory:') {
      throw StateError('Restore needs a file-based database.');
    }
    _db.dispose();
    File(source).copySync(path);
    _db = sqlite3.open(path);
    _db.execute('PRAGMA foreign_keys=ON');
  }

  void close() => _db.dispose();
}
