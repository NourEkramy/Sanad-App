import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../domain/backup.dart';
import 'drive_api.dart';

/// Google Drive through the user's Google account. Only the `drive.file`
/// scope is requested: Sanad sees nothing in Drive except the files it
/// created itself.
class GoogleDriveBackupStore implements CloudBackupStore {
  GoogleDriveBackupStore({DriveApi? api}) {
    _api = api ?? DriveApi(_accessToken);
  }

  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  static const _xlsx = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  late final DriveApi _api;
  Future<void>? _initialized;
  String? _token;

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  GoogleSignInAuthorizationClient get _client => GoogleSignIn.instance.authorizationClient;

  Future<void> _init() => _initialized ??= GoogleSignIn.instance.initialize();

  /// Silent: uses the access the user already granted.
  Future<String> _accessToken({bool refresh = false}) async {
    await _init();
    final current = _token;
    if (refresh && current != null) {
      await _client.clearAuthorizationToken(accessToken: current);
      _token = null;
    }
    if (_token case final token? when !refresh) return token;
    final authorization = await _guardSignIn(() => _client.authorizationForScopes(_scopes));
    if (authorization == null) throw const BackupFailure(BackupFailureReason.notAuthorized);
    return _token = authorization.accessToken;
  }

  @override
  Future<Result<String>> connect() => guard(() async {
    if (!isSupported) throw const BackupFailure(BackupFailureReason.unsupported);
    await _init();
    final authorization = await _guardSignIn(() => _client.authorizeScopes(_scopes));
    _token = authorization.accessToken;
    return await _api.accountEmail() ?? '';
  });

  @override
  Future<VoidResult> disconnect() => guard(() async {
    await _init();
    final token = _token;
    _token = null;
    if (token != null) await _client.clearAuthorizationToken(accessToken: token);
    // Also revokes the Drive permission; ignore failures (already revoked).
    try {
      await GoogleSignIn.instance.disconnect();
    } on GoogleSignInException {
      // Nothing to revoke.
    }
  });

  @override
  Future<Result<DateTime>> upload(BackupPayload payload) => guard(() async {
    final folder = await _api.ensureFolder(BackupFiles.folder);
    await _api.put(parent: folder, name: BackupFiles.workbook, mimeType: _xlsx, bytes: payload.workbook);
    final data = await _api.put(
      parent: folder,
      name: BackupFiles.data,
      mimeType: 'application/json',
      bytes: payload.data,
    );
    return data.modifiedAt;
  });

  @override
  Future<Result<RemoteBackup?>> latest() => guard(() async {
    final file = await _api.find(BackupFiles.data);
    return file == null ? null : RemoteBackup(modifiedAt: file.modifiedAt);
  });

  @override
  Future<Result<Uint8List>> download() => guard(() async {
    final file = await _api.find(BackupFiles.data);
    if (file == null) throw const BackupFailure(BackupFailureReason.noBackup);
    return _api.download(file.id);
  });

  static Future<T> _guardSignIn<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on GoogleSignInException catch (e) {
      throw switch (e.code) {
        GoogleSignInExceptionCode.canceled => const BackupFailure(BackupFailureReason.canceled),
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError => const BackupFailure(BackupFailureReason.notConfigured),
        _ => const BackupFailure(BackupFailureReason.notAuthorized),
      };
    }
  }
}
