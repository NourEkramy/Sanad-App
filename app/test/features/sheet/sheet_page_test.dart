import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/features/excel/domain/import/column_mapping.dart';
import 'package:sanad/features/excel/domain/import/import_planner.dart';
import 'package:sanad/features/sheet/domain/layout_detector.dart';
import 'package:sanad/features/sheet/domain/sheet_link.dart';
import 'package:sanad/features/sheet/domain/sheet_sync.dart';
import 'package:sanad/features/sheet/domain/sheet_usecases.dart';
import 'package:sanad/features/sheet/presentation/sheet_cubit.dart';
import 'package:sanad/features/sheet/presentation/sheet_page.dart';
import 'package:sanad/l10n/app_localizations_en.dart';

import '../../helpers/legacy_sheet.dart';
import '../../helpers/pump_app.dart';

class MockSheetCubit extends MockCubit<SheetLinkState> implements SheetCubit {}

final en = AppLocalizationsEn();
const url = 'https://script.google.com/macros/s/abc/exec';

SheetConnection connection({required bool phoneHasData}) {
  final table = legacySheet();
  final snapshot = SheetSnapshot(title: 'سند', tables: [table], contentHash: 'h');
  return SheetConnection(
    url: Uri.parse(url),
    pairing: const SheetPairing(key: 'K', title: 'سند'),
    snapshot: snapshot,
    detected: const SheetLayoutDetector().detect(snapshot),
    plan: const ImportPlanner(unspecifiedLabel: 'غير محدد').plan(table, const ColumnDetector().detect(table)!),
    phoneHasData: phoneHasData,
  );
}

SheetLink sheetLink({DateTime? lastSyncAt}) => SheetLink(
  url: Uri.parse(url),
  key: 'K',
  title: 'سند',
  layout: SheetLayout(visits: VisitsLayout.standard(), cases: CasesLayout.standard(), lists: ListsLayout.standard()),
  connectedAt: DateTime(2026, 10, 1),
  lastSyncAt: lastSyncAt,
);

void main() {
  late MockSheetCubit cubit;

  setUp(() {
    cubit = MockSheetCubit();
    when(() => cubit.connect(any(), code: any(named: 'code'))).thenAnswer((_) async {});
    when(() => cubit.loadFromSheet(replace: any(named: 'replace'))).thenAnswer((_) async {});
    when(() => cubit.keepPhoneData()).thenAnswer((_) async {});
    when(() => cubit.syncNow()).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, SheetLinkState state, {Locale locale = const Locale('en')}) async {
    whenListen(cubit, const Stream<SheetLinkState>.empty(), initialState: state);
    await tester.pumpApp(
      BlocProvider<SheetCubit>.value(value: cubit, child: const SheetPage()),
      locale: locale,
    );
  }

  testWidgets('not connected: the setup steps, the script to copy and the link field', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    await pump(tester, const SheetLinkState(loaded: true));
    expect(find.text(en.sheetStep1), findsOneWidget);
    expect(find.text(en.sheetStep4), findsOneWidget);

    await tester.ensureVisible(find.text(en.sheetCopyScript));
    await tester.pump();
    await tester.tap(find.text(en.sheetCopyScript));
    await tester.pumpAndSettle();
    expect(copied, contains('function doPost'));
    expect(find.text(en.sheetScriptCopied), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5)); // the message goes away

    await tester.enterText(find.byType(TextField), '  $url ');
    await tester.ensureVisible(find.text(en.sheetConnect));
    await tester.pump();
    await tester.tap(find.text(en.sheetConnect));
    verify(() => cubit.connect('  $url ', code: null)).called(1);
  });

  testWidgets('the connection code is asked for when another phone is connected', (tester) async {
    await pump(tester, const SheetLinkState(loaded: true, needsCode: true));
    expect(find.text(en.sheetCodeNeeded), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, url);
    await tester.enterText(find.byType(TextField).last, 'ABCD234567');
    await tester.ensureVisible(find.text(en.sheetConnect));
    await tester.pump();
    await tester.tap(find.text(en.sheetConnect));
    verify(() => cubit.connect(url, code: 'ABCD234567')).called(1);
  });

  testWidgets('Arabic: the setup screen lays out without overflow', (tester) async {
    await pump(tester, const SheetLinkState(loaded: true, needsCode: true), locale: const Locale('ar'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a sheet with data on a new phone: one button loads it', (tester) async {
    await pump(tester, SheetLinkState(loaded: true, connection: connection(phoneHasData: false)));
    expect(find.text(en.sheetFound), findsOneWidget);
    expect(find.text(en.sheetKeepPhoneData), findsNothing);
    await tester.ensureVisible(find.text(en.sheetLoad));
    await tester.pump();
    await tester.tap(find.text(en.sheetLoad));
    verify(() => cubit.loadFromSheet(replace: false)).called(1);
  });

  testWidgets('a phone that has data: replacing it is confirmed first', (tester) async {
    await pump(tester, SheetLinkState(loaded: true, connection: connection(phoneHasData: true)));
    expect(find.text(en.sheetPhoneHasData), findsOneWidget);
    await tester.ensureVisible(find.text(en.sheetUseSheetData));
    await tester.pump();
    await tester.tap(find.text(en.sheetUseSheetData));
    await tester.pumpAndSettle();
    expect(find.text(en.sheetReplaceConfirm), findsOneWidget);
    await tester.tap(find.text(en.sheetUseSheetData).last);
    await tester.pumpAndSettle();
    verify(() => cubit.loadFromSheet(replace: true)).called(1);
  });

  testWidgets('connected: what is waiting, and update now', (tester) async {
    await pump(tester, SheetLinkState(loaded: true, link: sheetLink(), pending: 3));
    expect(find.text(en.sheetWaiting(3)), findsOneWidget);
    expect(find.text(en.sheetNever), findsOneWidget);
    expect(find.textContaining('سجل الزيارات'), findsOneWidget);
    await tester.tap(find.text(en.sheetUpdateNow));
    verify(() => cubit.syncNow()).called(1);
  });

  testWidgets('a failure is explained', (tester) async {
    await pump(
      tester,
      SheetLinkState(
        loaded: true,
        link: sheetLink(lastSyncAt: DateTime(2026, 10, 11, 9, 30)),
        failure: const SheetFailure(SheetFailureReason.accessDenied),
      ),
    );
    expect(find.text(en.failureSheetAccessDenied), findsOneWidget);
    expect(find.text(en.sheetNotUpdated), findsOneWidget);
  });
}
