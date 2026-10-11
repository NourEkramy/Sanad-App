import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../utils/text_normalizer.dart';
import 'seed_data.dart';
import 'sheet_state.dart';

/// The on-device database (SQLite): the data the app works with. When a
/// Google Sheet is connected, every change is also written there (each row
/// carries a [SheetState]).
///
/// Business rules that the server used to enforce (unique phone, valid
/// references, frozen history) are enforced here by constraints and by the
/// repositories, which write only through [write].
class SanadDatabase {
  SanadDatabase._(this._db, this._clock);

  static const fileName = 'sanad.db';
  static const schemaVersion = 2;

  final Database _db;
  final DateTime Function() _clock;
  final _changes = StreamController<void>.broadcast();
  static const _uuid = Uuid();

  /// Opens (and on first run creates and seeds) the database at [path].
  /// Pass [inMemoryDatabasePath] for tests.
  static Future<SanadDatabase> open(DatabaseFactory factory, String path, {DateTime Function()? clock}) async {
    final now = clock ?? DateTime.now;
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await _run(db, _schema);
          await _migrate(db, 1, schemaVersion);
          await _seed(db, now);
        },
        onUpgrade: (db, from, to) => _migrate(db, from, to),
      ),
    );
    return SanadDatabase._(db, now);
  }

  /// Read access for queries.
  DatabaseExecutor get reader => _db;

  /// Emits after every committed change (used to update the Google Sheet).
  Stream<void> get changes => _changes.stream;

  String newId() => _uuid.v4();

  /// Current time as stored in the database (UTC, ISO 8601).
  String timestamp() => _clock().toUtc().toIso8601String();

  DateTime now() => _clock();

  /// Runs [action] in one transaction and announces the change ([notify]
  /// is false only for bookkeeping that is not a change of the data, such as
  /// marking rows as written to the Google Sheet).
  Future<T> write<T>(Future<T> Function(Transaction txn) action, {bool notify = true}) async {
    final result = await _db.transaction(action);
    if (notify) _changes.add(null);
    return result;
  }

  Future<void> close() async {
    await _changes.close();
    await _db.close();
  }

  /// Tables in dependency order (parents first).
  static const tables = [
    'import_batches',
    'areas',
    'nurses',
    'services',
    'customers',
    'service_records',
    'import_rows',
    'sheet_removals',
  ];

  /// Deletes all data and puts back the reference lists of a new install
  /// (used before loading everything from a Google Sheet).
  Future<void> reset() => write((txn) async {
    for (final table in tables.reversed) {
      await txn.delete(table);
    }
    await _seed(txn, _clock);
  });

  // ---------------------------------------------------------------------------
  // Schema
  // ---------------------------------------------------------------------------

  static Future<void> _run(DatabaseExecutor db, List<String> statements) async {
    final batch = db.batch();
    for (final statement in statements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _migrate(DatabaseExecutor db, int from, int to) async {
    for (var version = from + 1; version <= to; version++) {
      await _run(db, _migrations[version]!);
    }
  }

  /// Schema changes after version 1, by target version. New installs run
  /// them too, so every database goes through the same steps.
  static const Map<int, List<String>> _migrations = {
    2: [
      // Google Sheet link: where each row is in the sheet and whether it
      // still has to be written there (see SheetState).
      'ALTER TABLE service_records ADD COLUMN sheet_row INTEGER',
      'ALTER TABLE service_records ADD COLUMN sheet_state INTEGER NOT NULL DEFAULT ${SheetState.changed}',
      'ALTER TABLE customers ADD COLUMN sheet_row INTEGER',
      'ALTER TABLE customers ADD COLUMN sheet_state INTEGER NOT NULL DEFAULT ${SheetState.changed}',
      'ALTER TABLE areas ADD COLUMN sheet_state INTEGER NOT NULL DEFAULT ${SheetState.changed}',
      'ALTER TABLE nurses ADD COLUMN sheet_state INTEGER NOT NULL DEFAULT ${SheetState.changed}',
      'ALTER TABLE services ADD COLUMN sheet_state INTEGER NOT NULL DEFAULT ${SheetState.changed}',
      // Records deleted on the phone whose row must be cleared in the sheet.
      '''
      CREATE TABLE sheet_removals (
        record_id  TEXT PRIMARY KEY,
        sheet_row  INTEGER,
        created_at TEXT NOT NULL
      )''',
    ],
  };

  static Future<void> _seed(DatabaseExecutor db, DateTime Function() now) async {
    final at = now().toUtc().toIso8601String();
    final batch = db.batch();
    for (final name in SeedData.areas) {
      batch.insert('areas', {
        'id': _uuid.v4(),
        'name': name,
        'name_normalized': TextNormalizer.key(name),
        'created_at': at,
        'updated_at': at,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final (name, pounds) in SeedData.services) {
      batch.insert('services', {
        'id': _uuid.v4(),
        'name': name,
        'name_normalized': TextNormalizer.key(name),
        'default_price': pounds == null ? null : pounds * 100,
        'created_at': at,
        'updated_at': at,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  /// The schema of version 1 (1.0.2 and earlier), for upgrade tests.
  @visibleForTesting
  static List<String> get schemaV1 => _schema;

  // Version 1. Money is stored as integer piasters, dates as `yyyy-MM-dd`,
  // times as `HH:mm:ss`, timestamps as UTC ISO 8601, booleans as 0/1.
  static const _schema = [
    '''
    CREATE TABLE import_batches (
      id             TEXT PRIMARY KEY,
      file_name      TEXT NOT NULL,
      file_sha256    TEXT NOT NULL,
      sheet_name     TEXT NOT NULL,
      status         TEXT NOT NULL DEFAULT 'committed' CHECK (status IN ('committed', 'rolled_back')),
      summary        TEXT NOT NULL DEFAULT '{}',
      created_at     TEXT NOT NULL,
      rolled_back_at TEXT
    )''',
    // The same file may only be committed once at a time.
    "CREATE UNIQUE INDEX import_batches_file_committed_key ON import_batches (file_sha256) WHERE status = 'committed'",
    '''
    CREATE TABLE areas (
      id              TEXT PRIMARY KEY,
      name            TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 80),
      name_normalized TEXT NOT NULL UNIQUE,
      is_active       INTEGER NOT NULL DEFAULT 1,
      import_batch_id TEXT REFERENCES import_batches (id),
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL
    )''',
    '''
    CREATE TABLE nurses (
      id              TEXT PRIMARY KEY,
      name            TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 120),
      name_normalized TEXT NOT NULL UNIQUE,
      phone           TEXT,
      is_active       INTEGER NOT NULL DEFAULT 1,
      notes           TEXT CHECK (notes IS NULL OR length(notes) <= 1000),
      import_batch_id TEXT REFERENCES import_batches (id),
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL
    )''',
    '''
    CREATE TABLE services (
      id              TEXT PRIMARY KEY,
      name            TEXT NOT NULL CHECK (length(trim(name)) BETWEEN 1 AND 160),
      name_normalized TEXT NOT NULL UNIQUE,
      default_price   INTEGER CHECK (default_price IS NULL OR default_price >= 0),
      is_active       INTEGER NOT NULL DEFAULT 1,
      import_batch_id TEXT REFERENCES import_batches (id),
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL
    )''',
    '''
    CREATE TABLE customers (
      id              TEXT PRIMARY KEY,
      full_name       TEXT NOT NULL CHECK (length(trim(full_name)) BETWEEN 1 AND 160),
      name_normalized TEXT NOT NULL,
      phone           TEXT UNIQUE,
      address         TEXT CHECK (address IS NULL OR length(address) <= 500),
      area_id         TEXT NOT NULL REFERENCES areas (id),
      notes           TEXT CHECK (notes IS NULL OR length(notes) <= 2000),
      needs_review    INTEGER NOT NULL DEFAULT 0,
      import_batch_id TEXT REFERENCES import_batches (id),
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL,
      deleted_at      TEXT,
      CHECK (phone IS NOT NULL OR needs_review = 1)
    )''',
    'CREATE INDEX customers_name_idx ON customers (name_normalized)',
    'CREATE INDEX customers_area_idx ON customers (area_id)',
    'CREATE INDEX customers_created_at_idx ON customers (created_at)',
    '''
    CREATE TABLE service_records (
      id                      TEXT PRIMARY KEY,
      customer_id             TEXT NOT NULL REFERENCES customers (id),
      nurse_id                TEXT NOT NULL REFERENCES nurses (id),
      service_id              TEXT NOT NULL REFERENCES services (id),
      patient_name            TEXT CHECK (patient_name IS NULL OR length(patient_name) <= 160),
      patient_name_normalized TEXT,
      price                   INTEGER NOT NULL CHECK (price >= 0 AND price <= 100000000),
      payment_method          TEXT NOT NULL CHECK (payment_method IN ('cash', 'electronic', 'unspecified')),
      service_date            TEXT NOT NULL,
      service_time            TEXT,
      notes                   TEXT CHECK (notes IS NULL OR length(notes) <= 2000),
      -- Snapshot: how the record read when it was saved.
      area_id                 TEXT REFERENCES areas (id),
      customer_name_snapshot  TEXT NOT NULL DEFAULT '',
      customer_phone_snapshot TEXT,
      address_snapshot        TEXT,
      area_name_snapshot      TEXT NOT NULL DEFAULT '',
      nurse_name_snapshot     TEXT NOT NULL DEFAULT '',
      service_name_snapshot   TEXT NOT NULL DEFAULT '',
      legacy_ref              TEXT,
      import_batch_id         TEXT REFERENCES import_batches (id),
      created_at              TEXT NOT NULL,
      updated_at              TEXT NOT NULL,
      deleted_at              TEXT,
      CHECK (service_time IS NOT NULL OR import_batch_id IS NOT NULL),
      CHECK (payment_method <> 'unspecified' OR import_batch_id IS NOT NULL)
    )''',
    'CREATE INDEX service_records_customer_idx ON service_records (customer_id, service_date, service_time)',
    'CREATE INDEX service_records_date_idx ON service_records (service_date, service_time)',
    'CREATE INDEX service_records_batch_idx ON service_records (import_batch_id)',
    '''
    CREATE TABLE import_rows (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      batch_id   TEXT NOT NULL REFERENCES import_batches (id) ON DELETE CASCADE,
      row_number INTEGER NOT NULL,
      outcome    TEXT NOT NULL CHECK (outcome IN ('imported', 'skipped')),
      record_id  TEXT REFERENCES service_records (id) ON DELETE SET NULL,
      raw        TEXT NOT NULL,
      messages   TEXT NOT NULL DEFAULT '[]'
    )''',
    'CREATE INDEX import_rows_batch_idx ON import_rows (batch_id, row_number)',
  ];
}
