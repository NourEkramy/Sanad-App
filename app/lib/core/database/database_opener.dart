import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import 'sanad_database.dart';

/// Opens the app database: the app's private storage on Android/iOS, the
/// browser's IndexedDB on the web.
Future<SanadDatabase> openSanadDatabase() async {
  if (kIsWeb) return SanadDatabase.open(databaseFactoryFfiWeb, SanadDatabase.fileName);
  final directory = await getDatabasesPath();
  return SanadDatabase.open(databaseFactory, p.join(directory, SanadDatabase.fileName));
}
