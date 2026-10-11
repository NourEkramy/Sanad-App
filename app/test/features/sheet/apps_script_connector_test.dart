import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/features/excel/domain/entities/sheet_table.dart';
import 'package:sanad/features/sheet/data/apps_script_connector.dart';
import 'package:sanad/features/sheet/domain/sheet_sync.dart';
import 'package:sanad/features/sheet/domain/sheet_usecases.dart';

final url = Uri.parse('https://script.google.com/macros/s/abc/exec');

/// Answers like Google: the POST gets a 302 to the result, read with a GET.
MockClient google(Object? Function(Map<String, Object?> body) answer, {List<http.BaseRequest>? seen}) {
  final results = <String, String>{};
  return MockClient((request) async {
    seen?.add(request);
    if (request.method == 'POST') {
      final id = '${results.length + 1}';
      final out = answer((jsonDecode(request.body) as Map).cast<String, Object?>());
      results[id] = out is String ? out : jsonEncode(out);
      return http.Response('', 302, headers: {'location': 'https://script.googleusercontent.com/macros/echo?id=$id'});
    }
    return http.Response.bytes(utf8.encode(results[request.url.queryParameters['id']]!), 200);
  });
}

void main() {
  group('link', () {
    test('accepts the Web app URL and drops anything after it', () {
      expect(
        parseSheetLink(' https://script.google.com/macros/s/AKfy-1_x/exec?x=1#top ').valueOrNull,
        Uri.parse('https://script.google.com/macros/s/AKfy-1_x/exec'),
      );
      expect(
        parseSheetLink('https://script.google.com/a/macros/example.com/s/AKfy/exec').valueOrNull,
        Uri.parse('https://script.google.com/a/macros/example.com/s/AKfy/exec'),
      );
    });

    test('refuses other links, and explains the test (/dev) link', () {
      for (final text in [
        '',
        'not a link',
        'http://script.google.com/macros/s/a/exec',
        'https://docs.google.com/spreadsheets/d/abc/edit',
        'https://script.google.com/home/projects/abc/edit',
      ]) {
        expect(parseSheetLink(text).failureOrNull, const SheetFailure(SheetFailureReason.invalidLink), reason: text);
      }
      expect(
        parseSheetLink('https://script.google.com/macros/s/a/dev').failureOrNull,
        const SheetFailure(SheetFailureReason.invalidLink, '/dev'),
      );
    });

    test('accepts a local development server', () {
      expect(parseSheetLink('http://localhost:8787/exec').valueOrNull, Uri.parse('http://localhost:8787/exec'));
    });
  });

  group('requests', () {
    test('pairs: posts the action as JSON text and follows the redirect with a GET', () async {
      final seen = <http.BaseRequest>[];
      final connector = AppsScriptConnector(
        client: google((body) => {'ok': true, 'key': 'K123', 'title': 'سند', 'echo': body}, seen: seen),
      );
      final pairing = await connector.pair(url, code: 'CODE');
      expect(pairing.valueOrNull, const SheetPairing(key: 'K123', title: 'سند'));
      expect(seen.map((r) => r.method), ['POST', 'GET']);
      final post = seen.first as http.Request;
      expect(post.url, url);
      expect(post.headers['Content-Type'], startsWith('text/plain'), reason: 'no CORS preflight on the web');
      expect(jsonDecode(post.body), {'action': 'pair', 'key': 'CODE'});
      expect(post.followRedirects, isTrue, reason: 'a browser refuses redirects otherwise');
    });

    test('reads every sheet: dates, times, numbers and blanks', () async {
      final connector = AppsScriptConnector(
        client: google(
          (_) => {
            'ok': true,
            'title': 'Book',
            'sheets': [
              {
                'name': 'سجل الزيارات',
                'rows': [
                  ['م', 'تاريخ الزيارة', 'وقت الزيارة', 'ثمن', null],
                  [
                    1,
                    {'d': '2026-10-05'},
                    '9م',
                    120.5,
                    {'d': '2026-10-05 21:30'},
                  ],
                ],
              },
            ],
          },
        ),
      );
      final snapshot = (await connector.read(url, 'K')).valueOrNull!;
      expect(snapshot.title, 'Book');
      final table = snapshot.table('سجل الزيارات')!;
      expect(table.rows.first.last, SheetCell.empty);
      expect(table.rows[1], [
        const SheetCell(1),
        SheetCell(DateTime(2026, 10, 5)),
        const SheetCell('9م'),
        const SheetCell(120.5),
        SheetCell(DateTime(2026, 10, 5, 21, 30)),
      ]);
      expect(snapshot.contentHash, hasLength(64));
    });

    test('the content fingerprint changes with the content', () async {
      var rows = 1;
      final connector = AppsScriptConnector(
        client: google(
          (_) => {
            'ok': true,
            'title': 'Book',
            'sheets': [
              {
                'name': 'S',
                'rows': [
                  for (var i = 0; i < rows; i++) [i],
                ],
              },
            ],
          },
        ),
      );
      final first = (await connector.read(url, 'K')).valueOrNull!.contentHash;
      expect((await connector.read(url, 'K')).valueOrNull!.contentHash, first);
      rows = 2;
      expect((await connector.read(url, 'K')).valueOrNull!.contentHash, isNot(first));
    });

    test('writes the operations and returns the rows of every ID', () async {
      Map<String, Object?>? sent;
      final connector = AppsScriptConnector(
        client: google((body) {
          sent = body;
          return {
            'ok': true,
            'results': [
              {
                'sheet': 'سجل الزيارات',
                'rows': {'r1': 15, 'r2': null},
                'cols': {'م': 1},
                'missing': ['ملاحظات'],
              },
            ],
          };
        }),
      );
      const op = SheetOp(
        sheet: 'سجل الزيارات',
        headerRow: 3,
        stamps: [
          {'id': 'r1', 'row': 15},
        ],
      );
      final results = (await connector.write(url, 'K', const [op])).valueOrNull!;
      expect(
        results.single,
        const SheetWriteResult(sheet: 'سجل الزيارات', rows: {'r1': 15, 'r2': null}, missing: ['ملاحظات']),
      );
      expect(sent, {
        'action': 'write',
        'key': 'K',
        'ops': [op.toJson()],
      });
    });
  });

  group('failures', () {
    Future<Failure?> failureFor(MockClient client) async =>
        (await AppsScriptConnector(client: client).pair(url)).failureOrNull;
    MockClient status(int code, [String body = '']) => MockClient((_) async => http.Response(body, code));

    test('Google asking to sign in means the deployment is not open to Anyone', () async {
      expect(await failureFor(status(403)), const SheetFailure(SheetFailureReason.accessDenied));
      expect(await failureFor(status(401)), const SheetFailure(SheetFailureReason.accessDenied));
      expect(
        await failureFor(status(200, '<html><a href="https://accounts.google.com/ServiceLogin">Sign in</a></html>')),
        const SheetFailure(SheetFailureReason.accessDenied),
      );
    });

    test('a page that is not the script is not a Sanad link', () async {
      expect(await failureFor(status(404)), const SheetFailure(SheetFailureReason.invalidLink));
      expect(
        await failureFor(status(200, '<html>Script function not found: doPost</html>')),
        const SheetFailure(SheetFailureReason.invalidLink),
      );
      expect(await failureFor(status(200, '[1, 2]')), const SheetFailure(SheetFailureReason.invalidLink));
    });

    test('Google being down is retried later', () async {
      expect(await failureFor(status(503)), const ServerFailure('script_503'));
    });

    test('the script\'s own answers', () async {
      expect(
        await failureFor(google((_) => {'ok': false, 'error': 'code_required'})),
        const SheetFailure(SheetFailureReason.codeRequired),
      );
      expect(
        await failureFor(google((_) => {'ok': false, 'error': 'not_paired'})),
        const SheetFailure(SheetFailureReason.notPaired),
      );
      expect(
        await failureFor(google((_) => {'ok': false, 'error': 'server_error', 'message': 'Service timed out'})),
        const SheetFailure(SheetFailureReason.scriptError, 'Service timed out'),
      );
    });

    test('a sheet that disappeared, or a write the script refused', () async {
      Future<Failure?> writeFailure(Map<String, Object?> result) async => (await AppsScriptConnector(
        client: google(
          (_) => {
            'ok': true,
            'results': [result],
          },
        ),
      ).write(url, 'K', const [])).failureOrNull;
      expect(
        await writeFailure({'sheet': 'سجل الزيارات', 'error': 'sheet_not_found'}),
        const SheetFailure(SheetFailureReason.sheetMissing, 'سجل الزيارات'),
      );
      expect(
        await writeFailure({'sheet': 'S', 'error': 'boom'}),
        const SheetFailure(SheetFailureReason.scriptError, 'boom'),
      );
    });

    test('no connection, or no answer in time', () async {
      expect(
        await failureFor(MockClient((_) async => throw http.ClientException('Failed host lookup'))),
        const NetworkFailure(),
      );
      final slow = AppsScriptConnector(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 10),
      );
      expect((await slow.pair(url)).failureOrNull, const NetworkFailure());
    });
  });

  test('a real HTTP client follows the 302 Google sends after a POST', () async {
    // dart:io reports a 302 after a POST as "not a redirect"; this is what the
    // phone uses, so it is tested against a real server.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final methods = <String>[];
    unawaited(
      server.forEach((request) async {
        methods.add(request.method);
        if (request.method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          expect(jsonDecode(body), {'action': 'pair'});
          request.response
            ..statusCode = HttpStatus.found
            ..headers.set('Location', '/echo?id=1');
        } else {
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'ok': true, 'key': 'K', 'title': 'سند'}));
        }
        await request.response.close();
      }),
    );
    final connector = AppsScriptConnector(client: http.Client());
    final pairing = await connector.pair(Uri.parse('http://127.0.0.1:${server.port}/exec'));
    expect(pairing.valueOrNull, const SheetPairing(key: 'K', title: 'سند'));
    expect(methods, ['POST', 'GET']);
  });
}
