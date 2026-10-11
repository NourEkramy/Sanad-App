import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/database/sanad_database.dart';
import 'package:sanad/core/database/sheet_state.dart';
import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/areas/data/local_area_repository.dart';
import 'package:sanad/features/areas/domain/entities/area.dart';
import 'package:sanad/features/care_services/data/local_care_service_repository.dart';
import 'package:sanad/features/care_services/domain/entities/care_service.dart';
import 'package:sanad/features/customers/data/local_customer_repository.dart';
import 'package:sanad/features/customers/domain/entities/customer.dart';
import 'package:sanad/features/customers/domain/usecases/customer_usecases.dart';
import 'package:sanad/features/dashboard/data/local_dashboard_repository.dart';
import 'package:sanad/features/excel/data/excel_workbook_codec.dart';
import 'package:sanad/features/excel/data/local_excel_repositories.dart';
import 'package:sanad/features/excel/domain/excel_usecases.dart';
import 'package:sanad/features/excel/domain/export/export_models.dart';
import 'package:sanad/features/excel/domain/import/import_plan.dart';
import 'package:sanad/features/excel/domain/import/import_planner.dart';
import 'package:sanad/features/nurses/data/local_nurse_repository.dart';
import 'package:sanad/features/nurses/domain/entities/nurse.dart';
import 'package:sanad/features/records/data/local_record_repository.dart';
import 'package:sanad/features/records/domain/entities/record_draft.dart';
import 'package:sanad/features/records/domain/entities/record_filter.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';
import 'package:sanad/features/records/domain/usecases/record_usecases.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/database.dart';

void main() {
  late SanadDatabase db;
  late LocalAreaRepository areas;
  late LocalNurseRepository nurses;
  late LocalCareServiceRepository services;
  late LocalCustomerRepository customers;
  late LocalRecordRepository records;
  var ids = 0;
  final now = DateTime(2026, 10, 5, 18, 30);

  setUp(() async {
    db = await openTestDatabase(clock: () => now);
    areas = LocalAreaRepository(db);
    nurses = LocalNurseRepository(db);
    services = LocalCareServiceRepository(db);
    customers = LocalCustomerRepository(db);
    records = LocalRecordRepository(db);
  });

  tearDown(() => db.close());

  Future<Area> area(String name) async =>
      (await areas.getAreas()).valueOrNull!.firstWhere((a) => a.name == name, orElse: () => throw StateError(name));

  Future<Customer> newCustomer({String name = 'منى عادل', String phone = '01155555501', String? address}) async {
    final a = await area('البيطاش');
    return (await CreateCustomer(customers)(
      CustomerDraft(fullName: name, phone: phone, areaId: a.id, address: address),
    )).valueOrNull!;
  }

  Future<(Nurse, CareService)> nurseAndService() async {
    final existing = (await nurses.getNurses()).valueOrNull!.where((n) => n.name == 'سارة أحمد').firstOrNull;
    final nurse = existing ?? (await nurses.createNurse(name: 'سارة أحمد')).valueOrNull!;
    final service = (await services.getServices()).valueOrNull!.firstWhere((s) => s.name == 'حقن عضل');
    return (nurse, service);
  }

  Future<ServiceRecord> addRecord(
    Customer customer, {
    required Nurse nurse,
    required CareService service,
    String price = '75',
    PaymentMethod payment = PaymentMethod.cash,
    DateTime? date,
    LocalTime time = const LocalTime(10, 0),
    String? patient,
  }) async {
    final result = await AddServiceRecord(records, () => 'rec-${++ids}', clock: () => now)(
      customer,
      RecordDraft(
        nurseId: nurse.id,
        serviceId: service.id,
        price: price,
        paymentMethod: payment,
        serviceDate: date ?? DateTime(2026, 10, 5),
        serviceTime: time,
        patientName: patient,
      ),
    );
    return result.valueOrNull ?? (throw StateError('${result.failureOrNull}'));
  }

  group('reference data', () {
    test('the legacy price list and areas are seeded on first run', () async {
      expect((await areas.getAreas()).valueOrNull, hasLength(9));
      final list = (await services.getServices()).valueOrNull!;
      expect(list, hasLength(51));
      expect(list.firstWhere((s) => s.name == 'حقن عضل').defaultPrice, Money.pounds(75));
      expect(list.firstWhere((s) => s.name == 'صيدلية').defaultPrice, isNull, reason: '"**" = variable price');
    });

    test('names are unique regardless of Arabic spelling variants', () async {
      expect((await areas.createArea('ابو يوسف')).failureOrNull, const DuplicateFailure('name'));
      await nurses.createNurse(name: 'سارة أحمد');
      expect((await nurses.createNurse(name: 'ساره احمد')).failureOrNull, const DuplicateFailure('name'));
    });

    test('inactive items are hidden from pickers but kept', () async {
      final nurse = (await nurses.createNurse(name: 'يوسف')).valueOrNull!;
      await nurses.updateNurse(nurse.copyWith(isActive: false));
      expect((await nurses.getNurses()).valueOrNull, isEmpty);
      expect((await nurses.getNurses(includeInactive: true)).valueOrNull!.single.isActive, isFalse);
    });
  });

  group('customers', () {
    test('creating a customer with a phone that exists returns the existing customer', () async {
      final first = await newCustomer();
      final again = await CreateCustomer(customers)(
        CustomerDraft(fullName: 'Someone else', phone: '0115 555 5501', areaId: first.areaId),
      );
      expect(again.failureOrNull, CustomerExistsFailure(first));
    });

    test('the database itself refuses a duplicate phone', () async {
      final first = await newCustomer();
      final dup = await customers.create(fullName: 'X', phone: first.phone!, areaId: first.areaId);
      expect(dup.failureOrNull, const DuplicateFailure('phone'));
    });

    test('phone search: full, prefix, partial (4+ digits), Arabic digits and +20', () async {
      final mona = await newCustomer();
      await newCustomer(name: 'Ahmed Mohamed', phone: '01012345678');
      Future<List<String>> search(String q) async =>
          (await customers.search(q)).valueOrNull!.map((c) => c.fullName).toList();

      expect(await search('01155555501'), [mona.fullName]);
      expect(await search('0115'), [mona.fullName]);
      expect(await search('5550'), [mona.fullName], reason: 'contains, not only prefix');
      expect(await search('555'), isEmpty, reason: 'contains needs at least 4 digits');
      expect(await search('٠١١٥٥٥٥٥٥٠١'), [mona.fullName]);
      expect(await search('+20 115 555 5501'), [mona.fullName]);
      expect(await search('010'), ['Ahmed Mohamed']);
    });

    test('name search ignores Arabic spelling variants and case', () async {
      await newCustomer(name: 'أحمد عبد الله', phone: '01000000001');
      await newCustomer(name: 'Ahmed Mohamed', phone: '01012345678');
      expect((await customers.search('احمد')).valueOrNull!.single.fullName, 'أحمد عبد الله');
      expect((await customers.search('ahmed')).valueOrNull!.single.fullName, 'Ahmed Mohamed');
      expect((await customers.search('%')).valueOrNull, isEmpty, reason: 'LIKE wildcards are escaped');
    });

    test('archived customers are not found by search but keep their phone', () async {
      final mona = await newCustomer();
      await customers.setArchived(mona.id, archived: true);
      expect((await customers.search('0115')).valueOrNull, isEmpty);
      expect((await customers.findByPhone(mona.phone!)).valueOrNull!.isArchived, isTrue);
    });

    test('list shows visit count and last visit', () async {
      final mona = await newCustomer();
      final (nurse, service) = await nurseAndService();
      await addRecord(mona, nurse: nurse, service: service, date: DateTime(2026, 10, 1));
      await addRecord(mona, nurse: nurse, service: service, date: DateTime(2026, 10, 3));
      final listed = (await customers.list()).valueOrNull!.single;
      expect(listed.recordCount, 2);
      expect(listed.lastServiceDate, DateTime(2026, 10, 3));
      expect(listed.areaName, 'البيطاش');
    });
  });

  group('service records', () {
    test('a saved record belongs to its customer and stores the actual price and payment', () async {
      final mona = await newCustomer(address: 'ش 10');
      final (nurse, service) = await nurseAndService();
      final record = await addRecord(
        mona,
        nurse: nurse,
        service: service,
        price: '1,250.50',
        payment: PaymentMethod.electronic,
      );

      final stored = (await records.getById(record.id)).valueOrNull!;
      expect(stored.customerId, mona.id);
      expect(stored.customerPhone, mona.phone);
      expect(stored.price, const Money.piasters(125050));
      expect(stored.paymentMethod, PaymentMethod.electronic);
      expect(stored.nurseName, 'سارة أحمد');
      expect(stored.serviceName, 'حقن عضل');
      expect(stored.areaName, 'البيطاش');
      expect(stored.customerAddress, 'ش 10');
      expect(stored.serviceTime, const LocalTime(10, 0));
    });

    test('history never changes: renames, moves and new default prices do not touch old records', () async {
      final mona = await newCustomer(address: 'old address');
      final (nurse, service) = await nurseAndService();
      final record = await addRecord(mona, nurse: nurse, service: service);

      await nurses.updateNurse(nurse.copyWith(name: 'Sara A.'));
      await services.updateService(service.copyWith(name: 'IM injection', defaultPrice: Money.pounds(90)));
      final moved = await area('الهانوفيل');
      await customers.update(mona.id, fullName: mona.fullName, phone: mona.phone!, areaId: moved.id, address: 'new');
      await areas.updateArea((await area('البيطاش')).copyWith(name: 'Bitash'));

      final stored = (await records.getById(record.id)).valueOrNull!;
      expect(stored.price, Money.pounds(75));
      expect(stored.nurseName, 'سارة أحمد');
      expect(stored.serviceName, 'حقن عضل');
      expect(stored.areaName, 'البيطاش');
      expect(stored.customerAddress, 'old address');
    });

    test('saving the same record twice creates it once', () async {
      final mona = await newCustomer();
      final (nurse, service) = await nurseAndService();
      final draft = NewServiceRecord(
        id: 'fixed-id',
        customerId: mona.id,
        customerName: mona.fullName,
        customerPhone: mona.phone,
        nurseId: nurse.id,
        nurseName: nurse.name,
        serviceId: service.id,
        serviceName: service.name,
        price: Money.pounds(75),
        paymentMethod: PaymentMethod.cash,
        serviceDate: DateTime(2026, 10, 5),
        serviceTime: const LocalTime(9, 0),
        createdAt: now,
      );
      await records.add(draft);
      await records.add(draft);
      expect((await records.customerHistory(mona.id)).valueOrNull, hasLength(1));
    });

    test('inactive nurses/services and archived customers are rejected', () async {
      final mona = await newCustomer();
      final (nurse, service) = await nurseAndService();
      await nurses.updateNurse(nurse.copyWith(isActive: false));
      final rejected = await AddServiceRecord(records, () => 'x', clock: () => now)(
        mona,
        RecordDraft(
          nurseId: nurse.id,
          serviceId: service.id,
          price: '75',
          paymentMethod: PaymentMethod.cash,
          serviceDate: DateTime(2026, 10, 5),
          serviceTime: const LocalTime(9, 0),
        ),
      );
      expect(rejected.failureOrNull, const BusinessRuleFailure('nurse_inactive'));

      await nurses.updateNurse(nurse.copyWith(isActive: true));
      await customers.setArchived(mona.id, archived: true);
      expect(
        () => addRecord(mona, nurse: nurse, service: service),
        throwsA(isA<StateError>().having((e) => e.message, 'message', contains('customer_archived'))),
      );
    });

    test('history is newest first; archived records disappear', () async {
      final mona = await newCustomer();
      final (nurse, service) = await nurseAndService();
      final older = await addRecord(mona, nurse: nurse, service: service, date: DateTime(2026, 10, 1));
      await addRecord(mona, nurse: nurse, service: service, date: DateTime(2026, 10, 3), time: const LocalTime(8, 0));
      final latest = await addRecord(
        mona,
        nurse: nurse,
        service: service,
        date: DateTime(2026, 10, 3),
        time: const LocalTime(21, 0),
      );
      expect((await records.customerHistory(mona.id)).valueOrNull!.first.id, latest.id);

      await records.archive(older.id);
      expect((await records.customerHistory(mona.id)).valueOrNull, hasLength(2));
      expect((await records.getById(older.id)).valueOrNull!.isArchived, isTrue);
    });

    test('filters, search, sorting and totals agree', () async {
      final mona = await newCustomer();
      final ahmed = await newCustomer(name: 'Ahmed Mohamed', phone: '01012345678');
      final (nurse, service) = await nurseAndService();
      await addRecord(mona, nurse: nurse, service: service, price: '500', date: DateTime(2026, 10, 1));
      await addRecord(mona, nurse: nurse, service: service, price: '75', payment: PaymentMethod.electronic);
      await addRecord(ahmed, nurse: nurse, service: service, price: '100', patient: 'والدته');

      Future<List<int>> prices(RecordFilter f) async =>
          (await records.list(f)).valueOrNull!.map((r) => r.price.piasters ~/ 100).toList();

      expect(await prices(const RecordFilter(sort: RecordSort.priceHigh)), [500, 100, 75]);
      expect(await prices(const RecordFilter(paymentMethod: PaymentMethod.electronic)), [75]);
      expect(await prices(RecordFilter(from: DateTime(2026, 10, 2))), unorderedEquals([75, 100]));
      expect(await prices(const RecordFilter(query: '0101')), [100], reason: 'phone');
      expect(await prices(const RecordFilter(query: 'منى')), unorderedEquals([500, 75]), reason: 'customer name');
      expect(await prices(const RecordFilter(query: 'والدته')), [100], reason: 'patient name');

      final totals = (await records.totals(const RecordFilter(query: 'منى'))).valueOrNull!;
      expect(totals, const RecordTotals(count: 2, revenuePiasters: 57500));
    });

    test('correcting a record re-checks and snapshots a newly chosen nurse', () async {
      final mona = await newCustomer();
      final (nurse, service) = await nurseAndService();
      final record = await addRecord(mona, nurse: nurse, service: service);
      final other = (await nurses.createNurse(name: 'يوسف')).valueOrNull!;

      final updated = (await records.update(
        record.id,
        nurseId: other.id,
        serviceId: service.id,
        price: Money.pounds(80),
        paymentMethod: PaymentMethod.cash,
        serviceDate: record.serviceDate,
        serviceTime: record.serviceTime!,
      )).valueOrNull!;
      expect(updated.nurseName, 'يوسف');
      expect(updated.price, Money.pounds(80));
    });
  });

  test('dashboard counts today, this month and what needs review', () async {
    final mona = await newCustomer();
    final (nurse, service) = await nurseAndService();
    await addRecord(mona, nurse: nurse, service: service, price: '500');
    await addRecord(mona, nurse: nurse, service: service, price: '75', payment: PaymentMethod.electronic);
    await addRecord(mona, nurse: nurse, service: service, price: '100', date: DateTime(2026, 10, 1));
    await addRecord(mona, nurse: nurse, service: service, price: '40', date: DateTime(2026, 9, 30));

    final stats = (await LocalDashboardRepository(db).getStats(DateTime(2026, 10, 5))).valueOrNull!;
    expect(stats.totalCustomers, 1);
    expect(stats.totalRecords, 4);
    expect(stats.todayRecords, 2);
    expect(stats.todayRevenue, Money.pounds(575));
    expect(stats.todayCash, Money.pounds(500));
    expect(stats.todayElectronic, Money.pounds(75));
    expect(stats.monthRevenue, Money.pounds(675));
    expect(stats.activeNurses, 1);
    expect(stats.activeServices, 51);
  });

  group('Excel import', () {
    const codec = ExcelWorkbookCodec();
    late LocalImportRepository imports;
    late ImportPlan plan;

    setUp(() async {
      imports = LocalImportRepository(db);
      final bytes = File('test/fixtures/legacy_synthetic_openpyxl.xlsx').readAsBytesSync();
      final opened = const OpenWorkbook(codec)(fileName: 'legacy.xlsx', bytes: bytes).valueOrNull!;
      plan = const ImportPlanner(unspecifiedLabel: 'غير محدد').plan(
        opened.bestSheet!,
        opened.mappings['سجل الزيارات']!,
        existing: (await imports.existingData()).valueOrNull!,
      );
    });

    test('imports in one step, reusing what exists and never overwriting it', () async {
      final ahmed = await newCustomer(name: 'Ahmed (typed in the app)', phone: '01012345678');

      final result = (await imports.commit(plan, fileName: 'legacy.xlsx', fileSha256: 'abc')).valueOrNull!;

      expect(result.createdRecords, 5);
      expect(result.matchedCustomers, 1);
      expect(result.createdCustomers, 2, reason: '0115… and one without a valid phone');
      expect(result.createdNurses, 3, reason: 'سارة أحمد / سارة احمد merged');
      expect(result.createdServices, 1, reason: 'only the service missing from the price list');
      expect((await customers.getById(ahmed.id)).valueOrNull!.fullName, 'Ahmed (typed in the app)');
      expect((await customers.list(needsReviewOnly: true)).valueOrNull, hasLength(1));

      final all = (await records.list(const RecordFilter())).valueOrNull!;
      expect(all.every((r) => r.isImported), isTrue);
      expect(all.where((r) => r.paymentMethod == PaymentMethod.unspecified), hasLength(5));
      expect((await records.totals(const RecordFilter())).valueOrNull!.revenuePiasters, 89500);
      expect((await imports.batches()).valueOrNull!.single.recordCount, 5);
    });

    test('the same file cannot be imported twice; rollback removes exactly what it created', () async {
      final batch = (await imports.commit(plan, fileName: 'legacy.xlsx', fileSha256: 'abc')).valueOrNull!;
      expect(
        (await imports.commit(plan, fileName: 'legacy.xlsx', fileSha256: 'abc')).failureOrNull,
        const BusinessRuleFailure('already_imported'),
      );

      // A record added later to an imported customer keeps that customer.
      final mona = (await customers.findByPhone('01155555501')).valueOrNull!;
      final (nurse, service) = await nurseAndService();
      await addRecord(mona, nurse: nurse, service: service);

      expect((await imports.rollback(batch.batchId)).failureOrNull, isNull);
      expect((await records.list(const RecordFilter())).valueOrNull, hasLength(1));
      expect((await customers.list()).valueOrNull!.map((c) => c.phone), ['01155555501']);
      expect((await areas.getAreas()).valueOrNull!.map((a) => a.name), contains('سموحة'), reason: 'still used');
      expect((await services.getServices()).valueOrNull, hasLength(51));
      expect((await imports.batches()).valueOrNull!.single.isRolledBack, isTrue);
      expect((await imports.rollback(batch.batchId)).failureOrNull, const BusinessRuleFailure('batch_not_found'));

      // …and the file can be imported again after a rollback.
      expect((await imports.commit(plan, fileName: 'legacy.xlsx', fileSha256: 'abc')).failureOrNull, isNull);
    });

    test('export reads everything back for the workbook', () async {
      await imports.commit(plan, fileName: 'legacy.xlsx', fileSha256: 'abc');
      final data = (await LocalExportRepository(db).load(const ExportRequest())).valueOrNull!;
      expect(data.records, hasLength(5));
      expect(data.records.first.serviceDate.isAfter(data.records.last.serviceDate), isFalse, reason: 'oldest first');
      expect(data.customers, hasLength(3));
      expect(data.nurses, hasLength(3));
      expect(data.services, hasLength(52));
      expect(data.areas.length, greaterThanOrEqualTo(9));
    });
  });

  group('database', () {
    test('a database left by version 1.0.2 is upgraded and keeps its data', () async {
      final dir = await Directory.systemTemp.createTemp('sanad_db');
      addTearDown(() => dir.delete(recursive: true));
      final path = '${dir.path}/${SanadDatabase.fileName}';
      final at = now.toUtc().toIso8601String();
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (d, _) async {
            for (final statement in SanadDatabase.schemaV1) {
              await d.execute(statement);
            }
          },
        ),
      );
      await old.insert('areas', {
        'id': 'a1',
        'name': 'سموحة',
        'name_normalized': 'سموحه',
        'created_at': at,
        'updated_at': at,
      });
      await old.insert('customers', {
        'id': 'c1',
        'full_name': 'منى عادل',
        'name_normalized': 'مني عادل',
        'phone': '01155555501',
        'area_id': 'a1',
        'created_at': at,
        'updated_at': at,
      });
      await old.close();

      final upgraded = await SanadDatabase.open(databaseFactoryFfi, path, clock: () => now);
      addTearDown(upgraded.close);
      final version = await upgraded.reader.rawQuery('PRAGMA user_version');
      expect(version.single.values.single, SanadDatabase.schemaVersion);
      final row = (await upgraded.reader.query('customers')).single;
      expect(row['full_name'], 'منى عادل');
      expect(row['sheet_state'], SheetState.changed, reason: 'written to the sheet once one is connected');
      expect(row['sheet_row'], isNull);
      expect((await upgraded.reader.query('areas')).single['sheet_state'], SheetState.changed);
      expect(await upgraded.reader.query('sheet_removals'), isEmpty);
      expect((await LocalCustomerRepository(upgraded).list()).valueOrNull!.single.areaName, 'سموحة');
    });

    test('reset deletes everything and puts back the lists of a new install', () async {
      final mona = await newCustomer();
      final (nurse, service) = await nurseAndService();
      await addRecord(mona, nurse: nurse, service: service);
      await areas.createArea('العجمي');

      await db.reset();
      expect((await customers.list()).valueOrNull, isEmpty);
      expect((await records.list(const RecordFilter())).valueOrNull, isEmpty);
      expect((await nurses.getNurses(includeInactive: true)).valueOrNull, isEmpty);
      expect((await services.getServices()).valueOrNull, hasLength(51));
      expect((await areas.getAreas()).valueOrNull!.map((a) => a.name), isNot(contains('العجمي')));
      expect((await areas.getAreas()).valueOrNull, hasLength(9));
    });

    test('every change is announced (to update the sheet)', () async {
      final events = <void>[];
      final sub = db.changes.listen(events.add);
      await newCustomer();
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      await sub.cancel();
    });
  });
}
