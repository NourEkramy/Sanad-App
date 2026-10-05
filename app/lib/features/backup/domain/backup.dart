import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/storage/secure_store.dart';

/// The files kept in the "Sanad" folder of the user's Google Drive.
abstract final class BackupFiles {
  static const folder = 'Sanad';

  /// Formatted workbook with every sheet — the copy to open and share.
  static const workbook = 'Sanad.xlsx';

  /// Complete data in JSON — what "Restore" reads back.
  static const data = 'Sanad-backup.json';
}

/// What is uploaded on each backup.
class BackupPayload {
  const BackupPayload({required this.workbook, required this.data});

  final Uint8List workbook;
  final Uint8List data;
}

/// A backup found in Google Drive.
class RemoteBackup extends Equatable {
  const RemoteBackup({required this.modifiedAt});

  final DateTime modifiedAt;

  @override
  List<Object?> get props => [modifiedAt];
}

/// The user's own Google Drive (only files created by Sanad are visible to
/// the app: `drive.file` scope).
abstract interface class CloudBackupStore {
  /// False where Drive backup is not available (web, desktop).
  bool get isSupported;

  /// Asks the user to choose a Google account and allow Drive access.
  /// Must be called from a user action. Returns the account's e-mail.
  Future<Result<String>> connect();

  Future<VoidResult> disconnect();

  /// Uploads both files, replacing the previous backup (Drive keeps earlier
  /// versions in the file's version history).
  Future<Result<DateTime>> upload(BackupPayload payload);

  /// The backup currently in Drive, or null when there is none.
  Future<Result<RemoteBackup?>> latest();

  /// Contents of [BackupFiles.data].
  Future<Result<Uint8List>> download();
}

/// The local side: what is backed up and how a backup is applied.
abstract interface class BackupSource {
  Future<Result<BackupPayload>> create();

  /// Replaces all local data with [data] (contents of [BackupFiles.data]).
  Future<VoidResult> restore(Uint8List data);

  /// Emits after every change to the local data.
  Stream<void> get changes;
}

/// Backup preferences and status, remembered on the device.
class BackupPrefs extends Equatable {
  const BackupPrefs({this.account, this.lastBackupAt, this.pendingSince});

  /// Connected Google account (null = not connected).
  final String? account;
  final DateTime? lastBackupAt;

  /// Time of the first change not yet in Drive (null = up to date).
  final DateTime? pendingSince;

  bool get connected => account != null;

  Map<String, Object?> toJson() => {
    'account': account,
    'lastBackupAt': lastBackupAt?.toIso8601String(),
    'pendingSince': pendingSince?.toIso8601String(),
  };

  static BackupPrefs fromJson(Map<String, Object?> json) => BackupPrefs(
    account: json['account'] as String?,
    lastBackupAt: DateTime.tryParse(json['lastBackupAt'] as String? ?? ''),
    pendingSince: DateTime.tryParse(json['pendingSince'] as String? ?? ''),
  );

  @override
  List<Object?> get props => [account, lastBackupAt, pendingSince];
}

class BackupPrefsStore {
  const BackupPrefsStore(this._store);

  final KeyValueStore _store;
  static const _key = 'sanad.backup';

  Future<BackupPrefs> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return const BackupPrefs();
    try {
      return BackupPrefs.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return const BackupPrefs();
    }
  }

  Future<void> write(BackupPrefs prefs) => _store.write(_key, jsonEncode(prefs.toJson()));
}

/// Creates the backup files and uploads them.
class BackUpNow {
  const BackUpNow(this._source, this._cloud);

  final BackupSource _source;
  final CloudBackupStore _cloud;

  Future<Result<DateTime>> call() async {
    final payload = await _source.create();
    return switch (payload) {
      Success(:final value) => _cloud.upload(value),
      Err(:final failure) => Result.failure(failure),
    };
  }
}

/// Replaces local data with the backup in Drive.
class RestoreFromDrive {
  const RestoreFromDrive(this._source, this._cloud);

  final BackupSource _source;
  final CloudBackupStore _cloud;

  Future<VoidResult> call() async {
    final data = await _cloud.download();
    return switch (data) {
      Success(:final value) => _source.restore(value),
      Err(:final failure) => Result.failure(failure),
    };
  }
}

/// True for failures worth retrying automatically later (no connection).
bool isTransientBackupFailure(Failure failure) => failure is NetworkFailure;
