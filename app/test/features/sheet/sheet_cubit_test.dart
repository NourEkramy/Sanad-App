import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/database/sanad_database.dart';
import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/core/network/connectivity_service.dart';
import 'package:sanad/core/result/result.dart';
import 'package:sanad/core/storage/secure_store.dart';
import 'package:sanad/features/areas/data/local_area_repository.dart';
import 'package:sanad/features/excel/data/local_excel_repositories.dart';
import 'package:sanad/features/excel/domain/entities/sheet_table.dart';
import 'package:sanad/features/sheet/data/local_sheet_store.dart';
import 'package:sanad/features/sheet/domain/sheet_link.dart';
import 'package:sanad/features/sheet/domain/sheet_sync.dart';
import 'package:sanad/features/sheet/domain/sheet_usecases.dart';
import 'package:sanad/features/sheet/presentation/sheet_cubit.dart';

import '../../helpers/database.dart';
import '../../helpers/legacy_sheet.dart';

const link = 'https://script.google.com/macros/s/abc/exec';

class FakeConnector implements SheetConnector {
  SheetSnapshot snapshot = const SheetSnapshot(title: 'Book', tables: [], contentHash: 'empty');
  String? code;
  Failure? writeFailure;
  final writes = <List<SheetOp>>[];

  @override
  Future<Result<SheetPairing>> pair(Uri url, {String? code}) async {
    if (this.code != null && code != this.code) {
      return const Result.failure(SheetFailure(SheetFailureReason.codeRequired));
    }
    return const Result.success(SheetPairing(key: 'KEY', title: 'Book'));
  }

  @override
  Future<Result<SheetSnapshot>> read(Uri url, String key) async => Result.success(snapshot);

  @override
  Future<Result<List<SheetWriteResult>>> write(Uri url, String key, List<SheetOp> ops) async {
    if (writeFailure case final failure?) return Result.failure(failure);
    writes.add(ops);
    return Result.success([
      for (final op in ops)
        SheetWriteResult(
          sheet: op.sheet,
          rows: {
            for (final u in [...op.upserts, ...op.stamps]) u['id']! as String: 5,
          },
        ),
    ]);
  }
}

class FakeConnectivity implements ConnectivityService {
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => controller.stream;
}

void main() {
  late SanadDatabase db;
  late FakeConnector connector;
  late FakeConnectivity connectivity;
  late SheetLinkStore links;
  late SheetCubit cubit;

  setUp(() async {
    db = await openTestDatabase();
    connector = FakeConnector();
    connectivity = FakeConnectivity();
    links = SheetLinkStore(MemoryStore());
    final store = LocalSheetStore(db);
    final imports = LocalImportRepository(db);
    cubit = SheetCubit(
      connect: ConnectSheet(connector, store, imports),
      linkSheet: LinkSheet(store, imports, links),
      sync: SyncSheet(connector, store, links),
      store: store,
      links: links,
      connectivity: connectivity,
      unspecifiedLabel: () => 'غير محدد',
      delay: const Duration(milliseconds: 20),
    );
    await cubit.start();
  });

  tearDown(() async {
    await cubit.close();
    await connectivity.controller.close();
    await db.close();
  });

  Future<SheetLinkState> until(bool Function(SheetLinkState s) test) async =>
      test(cubit.state) ? cubit.state : cubit.stream.firstWhere(test).timeout(const Duration(seconds: 5));

  test('starts without a sheet; the built-in lists wait to be written', () {
    expect(cubit.state.loaded, isTrue);
    expect(cubit.state.connected, isFalse);
    expect(cubit.state.pending, 60);
  });

  test('a wrong link is refused before anything is sent', () async {
    await cubit.connect('https://docs.google.com/spreadsheets/d/x/edit');
    expect(cubit.state.failure, const SheetFailure(SheetFailureReason.invalidLink));
    expect(cubit.state.busy, isFalse);
    expect(connector.writes, isEmpty);
  });

  test('a sheet used by another phone asks for its connection code', () async {
    connector.code = 'CODE';
    await cubit.connect(link);
    expect(cubit.state.needsCode, isTrue);
    expect(cubit.state.failure, isNull);

    await cubit.connect(link, code: 'CODE');
    expect(cubit.state.needsCode, isFalse);
    expect(cubit.state.connected, isTrue);
  });

  test("an empty sheet simply receives the phone's data", () async {
    await cubit.connect(link);
    expect(cubit.state.connected, isTrue);
    expect(cubit.state.connection, isNull);
    expect(connector.writes, hasLength(1));
    expect(cubit.state.pending, 0);
    expect(cubit.state.upToDate, isTrue);
    expect((await links.read())!.lastSyncAt, isNotNull);
  });

  test('a sheet with data waits for the choice, then loads it and asks every screen to reload', () async {
    connector.snapshot = SheetSnapshot(title: 'Book', tables: [legacySheet()], contentHash: 'h');
    await cubit.connect(link);
    expect(cubit.state.connected, isFalse);
    expect(cubit.state.connection?.sheetHasData, isTrue);
    expect(cubit.state.connection?.phoneHasData, isFalse);

    await cubit.loadFromSheet(replace: false);
    expect(cubit.state.connected, isTrue);
    expect(cubit.state.reloadCount, 1);
    expect(cubit.state.connection, isNull);
    expect(connector.writes.expand((ops) => ops).any((op) => op.stamps.isNotEmpty), isTrue);
    expect(cubit.state.upToDate, isTrue);
  });

  test('a customer in both the visits and the customers sheet is counted once', () async {
    const cases = SheetTable(
      name: 'بيانات الحالات',
      rows: [
        [SheetCell('اسم المريض / الحالة'), SheetCell('رقم التليفون')],
        [SheetCell('عميل أول'), SheetCell('01011111111')],
        [SheetCell('عميل جديد'), SheetCell('01099999999')],
      ],
    );
    connector.snapshot = SheetSnapshot(title: 'Book', tables: [legacySheet(), cases], contentHash: 'h');
    await cubit.connect(link);
    final connection = cubit.state.connection!;
    expect(connection.customerCount, connection.plan!.customers.length + 1);
  });

  test('changes are written a moment after they are made', () async {
    await cubit.connect(link);
    final before = connector.writes.length;
    await LocalAreaRepository(db).createArea('منطقة جديدة');
    await until((s) => s.pending == 1);
    await until((s) => s.pending == 0 && !s.busy);
    expect(connector.writes.length, before + 1);
    expect(connector.writes.last.single.appends.single['value'], 'منطقة جديدة');
  });

  test('offline: the failure is shown and the change is written when the connection is back', () async {
    await cubit.connect(link);
    connector.writeFailure = const NetworkFailure();
    await LocalAreaRepository(db).createArea('منطقة جديدة');
    await until((s) => s.failure == const NetworkFailure());
    expect(cubit.state.pending, 1);
    expect(cubit.state.upToDate, isFalse);

    connector.writeFailure = null;
    connectivity.controller.add(true);
    final done = await until((s) => s.pending == 0 && s.failure == null && !s.busy);
    expect(done.upToDate, isTrue);
  });

  test('going to the background writes at once', () async {
    await cubit.connect(link);
    await cubit.close();
    // A fresh cubit with a long delay: only appPaused can write in time.
    final store = LocalSheetStore(db);
    final imports = LocalImportRepository(db);
    cubit = SheetCubit(
      connect: ConnectSheet(connector, store, imports),
      linkSheet: LinkSheet(store, imports, links),
      sync: SyncSheet(connector, store, links),
      store: store,
      links: links,
      connectivity: connectivity,
      unspecifiedLabel: () => 'غير محدد',
      delay: const Duration(hours: 1),
    );
    await cubit.start();
    await LocalAreaRepository(db).createArea('منطقة جديدة');
    await until((s) => s.pending == 1);
    cubit.appPaused();
    await until((s) => s.pending == 0 && !s.busy);
  });

  test('disconnecting stops writing and forgets the link', () async {
    await cubit.connect(link);
    await cubit.disconnect();
    expect(cubit.state.connected, isFalse);
    expect(await links.read(), isNull);
    final before = connector.writes.length;
    await LocalAreaRepository(db).createArea('منطقة جديدة');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(connector.writes.length, before);
  });
}
