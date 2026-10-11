import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../excel/domain/entities/sheet_table.dart';
import '../domain/sheet_sync.dart';

/// The connector script deployed as a Web app in the user's spreadsheet
/// (`tools/google-sheets/Code.gs`). Plain HTTPS: no Google sign-in in the app.
class AppsScriptConnector implements SheetConnector {
  AppsScriptConnector({http.Client? client, this.timeout = const Duration(seconds: 60)})
    : _http = client ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  @override
  Future<Result<SheetPairing>> pair(Uri url, {String? code}) => guard(() async {
    final (json, _) = await _call(url, {'action': 'pair', 'key': ?code});
    return SheetPairing(key: json['key']! as String, title: json['title'] as String? ?? '');
  });

  @override
  Future<Result<SheetSnapshot>> read(Uri url, String key) => guard(() async {
    final (json, body) = await _call(url, {'action': 'read', 'key': key});
    return SheetSnapshot(
      title: json['title'] as String? ?? '',
      contentHash: sha256.convert(utf8.encode(body)).toString(),
      tables: [
        for (final sheet in (json['sheets'] as List? ?? const []).cast<Map<String, Object?>>())
          SheetTable(
            name: sheet['name']! as String,
            rows: [
              for (final row in (sheet['rows'] as List? ?? const []).cast<List<Object?>>())
                [for (final value in row) _cell(value)],
            ],
          ),
      ],
    );
  });

  @override
  Future<Result<List<SheetWriteResult>>> write(Uri url, String key, List<SheetOp> ops) => guard(() async {
    final (json, _) = await _call(url, {
      'action': 'write',
      'key': key,
      'ops': [for (final op in ops) op.toJson()],
    });
    final results = [
      for (final r in (json['results'] as List? ?? const []).cast<Map<String, Object?>>())
        SheetWriteResult(
          sheet: r['sheet'] as String? ?? '',
          rows: {
            for (final MapEntry(:key, :value) in ((r['rows'] as Map?) ?? const {}).entries)
              key as String: (value as num?)?.toInt(),
          },
          missing: [...((r['missing'] as List?) ?? const []).cast<String>()],
          error: r['error'] as String?,
        ),
    ];
    for (final r in results) {
      if (r.error == 'sheet_not_found') throw SheetFailure(SheetFailureReason.sheetMissing, r.sheet);
      if (r.error != null) throw SheetFailure(SheetFailureReason.scriptError, r.error);
    }
    return results;
  });

  static SheetCell _cell(Object? value) => switch (value) {
    null => SheetCell.empty,
    {'d': final String d} => SheetCell(_date(d)),
    String() || num() || bool() => SheetCell(value),
    _ => SheetCell(value.toString()),
  };

  static Object _date(String text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?: (\d{2}):(\d{2}))?$').firstMatch(text);
    if (m == null) return text;
    int at(int i) => int.parse(m.group(i) ?? '0');
    return DateTime(at(1), at(2), at(3), at(4), at(5));
  }

  static const _redirects = {301, 302, 303, 307, 308};

  /// POSTs [body] and returns the decoded answer. Google answers a script
  /// POST with a 302 redirect to the result, to be fetched with a GET: the
  /// browser does that itself; on the phone the 302 comes back (dart:io
  /// follows a POST only after a 303) and is followed here. `isRedirect`
  /// cannot be used: for a POST it is true only for 303.
  Future<(Map<String, Object?>, String)> _call(Uri url, Map<String, Object?> body) async {
    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'text/plain;charset=utf-8'
      ..body = jsonEncode(body);
    var response = await http.Response.fromStream(await _http.send(request).timeout(timeout));
    for (var hops = 0; hops < 5 && _redirects.contains(response.statusCode); hops++) {
      final location = response.headers['location'];
      if (location == null) break;
      response = await _http.get(url.resolve(location)).timeout(timeout);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const SheetFailure(SheetFailureReason.accessDenied);
    }
    if (response.statusCode >= 500) throw ServerFailure('script_${response.statusCode}');
    if (response.statusCode != 200) throw const SheetFailure(SheetFailureReason.invalidLink);

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      // A Google sign-in page means the deployment is not open to "Anyone".
      throw SheetFailure(
        text.contains('accounts.google.com') || text.contains('ServiceLogin')
            ? SheetFailureReason.accessDenied
            : SheetFailureReason.invalidLink,
      );
    }
    if (json is! Map<String, Object?>) throw const SheetFailure(SheetFailureReason.invalidLink);
    if (json['ok'] != true) {
      throw switch (json['error']) {
        'code_required' => const SheetFailure(SheetFailureReason.codeRequired),
        'not_paired' => const SheetFailure(SheetFailureReason.notPaired),
        final error => SheetFailure(SheetFailureReason.scriptError, (json['message'] ?? error)?.toString()),
      };
    }
    return (json, text);
  }
}
