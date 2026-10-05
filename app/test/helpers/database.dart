import 'package:sanad/core/database/sanad_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A fresh, seeded in-memory database (real SQLite through FFI).
Future<SanadDatabase> openTestDatabase({DateTime Function()? clock}) {
  sqfliteFfiInit();
  return SanadDatabase.open(databaseFactoryFfi, inMemoryDatabasePath, clock: clock);
}
