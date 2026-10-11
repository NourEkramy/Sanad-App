import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/features/sheet/domain/sheet_link.dart';

void main() {
  test('the app ships the same connector script as tools/google-sheets', () {
    final shipped = File('assets/google_sheets/Code.gs').readAsStringSync();
    expect(shipped, File('../tools/google-sheets/Code.gs').readAsStringSync());
    expect(shipped, contains("idHeader: '$sanadIdHeader'"), reason: 'both sides use the same ID column');
  });
}
