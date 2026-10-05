import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/errors/failure.dart';

/// Supplies an OAuth access token for the `drive.file` scope. [refresh]
/// discards a cached token that the server rejected.
typedef AccessTokenProvider = Future<String> Function({bool refresh});

/// Minimal Google Drive v3 REST client: one folder, files replaced in place.
class DriveApi {
  DriveApi(this._token, {http.Client? client}) : _http = client ?? http.Client();

  final AccessTokenProvider _token;
  final http.Client _http;

  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';
  static const folderMime = 'application/vnd.google-apps.folder';

  Future<String?> accountEmail() async {
    final json = await _json('GET', Uri.parse('$_api/about?fields=user(emailAddress)'));
    return (json['user'] as Map?)?['emailAddress'] as String?;
  }

  /// Id of the folder named [name] at the top of My Drive, created if missing.
  Future<String> ensureFolder(String name) async {
    final existing = await find(name, mimeType: folderMime);
    if (existing != null) return existing.id;
    final json = await _json(
      'POST',
      Uri.parse('$_api/files?fields=id'),
      body: jsonEncode({'name': name, 'mimeType': folderMime}),
      contentType: 'application/json',
    );
    return json['id']! as String;
  }

  /// The newest non-trashed file named [name] (in [parent] when given).
  Future<DriveFile?> find(String name, {String? parent, String? mimeType}) async {
    final q = [
      "name = '${_quote(name)}'",
      'trashed = false',
      if (parent != null) "'${_quote(parent)}' in parents",
      if (mimeType != null) "mimeType = '$mimeType'",
    ].join(' and ');
    final uri = Uri.parse('$_api/files').replace(
      queryParameters: {
        'q': q,
        'spaces': 'drive',
        'orderBy': 'modifiedTime desc',
        'pageSize': '1',
        'fields': 'files(id,modifiedTime)',
      },
    );
    final files = (await _json('GET', uri))['files'] as List? ?? const [];
    if (files.isEmpty) return null;
    return DriveFile.fromJson((files.first as Map).cast<String, Object?>());
  }

  /// Creates [name] in [parent], or replaces the content of the existing file
  /// (keeping its sharing settings and version history).
  Future<DriveFile> put({
    required String parent,
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final existing = await find(name, parent: parent);
    if (existing != null) {
      final json = await _json(
        'PATCH',
        Uri.parse('$_upload/files/${existing.id}?uploadType=media&fields=id,modifiedTime'),
        bytes: bytes,
        contentType: mimeType,
      );
      return DriveFile.fromJson(json);
    }
    const boundary = 'sanad-backup-boundary';
    final metadata = jsonEncode({
      'name': name,
      'parents': [parent],
      'mimeType': mimeType,
    });
    final body = BytesBuilder()
      ..add(utf8.encode('--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n'))
      ..add(utf8.encode('--$boundary\r\nContent-Type: $mimeType\r\n\r\n'))
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final json = await _json(
      'POST',
      Uri.parse('$_upload/files?uploadType=multipart&fields=id,modifiedTime'),
      bytes: body.takeBytes(),
      contentType: 'multipart/related; boundary=$boundary',
    );
    return DriveFile.fromJson(json);
  }

  Future<Uint8List> download(String fileId) async {
    final response = await _send('GET', Uri.parse('$_api/files/$fileId?alt=media'));
    return response.bodyBytes;
  }

  Future<Map<String, Object?>> _json(
    String method,
    Uri uri, {
    String? body,
    Uint8List? bytes,
    String? contentType,
  }) async {
    final response = await _send(method, uri, body: body, bytes: bytes, contentType: contentType);
    return (jsonDecode(response.body) as Map).cast<String, Object?>();
  }

  Future<http.Response> _send(String method, Uri uri, {String? body, Uint8List? bytes, String? contentType}) async {
    Future<http.Response> attempt({required bool refresh}) async {
      final request = http.Request(method, uri)..headers['Authorization'] = 'Bearer ${await _token(refresh: refresh)}';
      if (contentType != null) request.headers['Content-Type'] = contentType;
      if (body != null) request.body = body;
      if (bytes != null) request.bodyBytes = bytes;
      return http.Response.fromStream(await _http.send(request));
    }

    var response = await attempt(refresh: false);
    // An expired token is refreshed once.
    if (response.statusCode == 401) response = await attempt(refresh: true);
    if (response.statusCode >= 200 && response.statusCode < 300) return response;
    throw switch (response.statusCode) {
      401 || 403 => const BackupFailure(BackupFailureReason.notAuthorized),
      _ => ServerFailure('drive_${response.statusCode}'),
    };
  }

  static String _quote(String value) => value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}

class DriveFile {
  const DriveFile({required this.id, required this.modifiedAt});

  factory DriveFile.fromJson(Map<String, Object?> json) => DriveFile(
    id: json['id']! as String,
    modifiedAt: DateTime.tryParse(json['modifiedTime'] as String? ?? '')?.toLocal() ?? DateTime.now(),
  );

  final String id;
  final DateTime modifiedAt;
}
