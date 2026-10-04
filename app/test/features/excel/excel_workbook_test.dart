import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/core/result/result.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/areas/domain/entities/area.dart';
import 'package:sanad/features/care_services/domain/entities/care_service.dart';
import 'package:sanad/features/excel/data/excel_workbook_codec.dart';
import 'package:sanad/features/excel/domain/excel_repositories.dart';
import 'package:sanad/features/excel/domain/excel_usecases.dart';
import 'package:sanad/features/excel/domain/export/export_models.dart';
import 'package:sanad/features/excel/domain/import/column_mapping.dart';
import 'package:sanad/features/excel/domain/import/import_planner.dart';
import 'package:sanad/features/nurses/domain/entities/nurse.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';

import '../../helpers/fakes.dart';

ServiceRecord record({
  required String id,
  required String customerName,
  required String phone,
  required int price,
  required PaymentMethod payment,
  required DateTime date,
  LocalTime? time = const LocalTime(19, 30),
  String? patient,
  String? notes,
}) => ServiceRecord(
  id: id,
  customerId: 'cust-$phone',
  customerName: customerName,
  customerPhone: phone,
  customerAddress: 'Street 1',
  areaName: 'Smouha',
  patientName: patient,
  nurseId: 'n1',
  nurseName: 'Sara Ahmed',
  serviceId: 's1',
  serviceName: 'Home Nursing Visit',
  price: Money.pounds(price),
  paymentMethod: payment,
  serviceDate: date,
  serviceTime: time,
  notes: notes,
  createdAt: DateTime(2026, 9, 12, 20),
);

final data = ExportData(
  records: [
    record(
      id: 'r1',
      customerName: 'Ahmed Mohamed',
      phone: '01012345678',
      price: 500,
      payment: PaymentMethod.cash,
      date: DateTime(2026, 9, 12),
    ),
    record(
      id: 'r2',
      customerName: 'Ahmed Mohamed',
      phone: '01012345678',
      price: 250,
      payment: PaymentMethod.electronic,
      date: DateTime(2026, 9, 13),
      patient: 'His mother',
      notes: 'Follow-up',
    ),
    record(
      id: 'r3',
      customerName: 'Mona Adel',
      phone: '01112345678',
      price: 75,
      payment: PaymentMethod.unspecified,
      date: DateTime(2026, 6, 20),
      time: null,
    ),
  ],
  customers: [
    customer(),
    customer(id: 'c2', name: 'Mona Adel', phone: '01112345678'),
  ],
  nurses: const [
    Nurse(id: 'n1', name: 'Sara Ahmed', phone: '01000000000'),
    Nurse(id: 'n2', name: 'Old', isActive: false),
  ],
  services: const [
    CareService(id: 's1', name: 'Home Nursing Visit', defaultPrice: Money.piasters(50000)),
    CareService(id: 's2', name: 'Pharmacy'),
  ],
  areas: const [Area(id: 'a1', name: 'Smouha')],
);

class _Repo implements ExportRepository {
  ExportRequest? request;
  @override
  Future<Result<ExportData>> load(ExportRequest request) async {
    this.request = request;
    return Result.success(data);
  }
}

void main() {
  const codec = ExcelWorkbookCodec();

  test('export creates a formatted workbook with one sheet per entity', () {
    final bytes = codec.encodeExport(data, ExportLabels.english, {...ExportSheet.values}).valueOrNull!;
    final book = xl.Excel.decodeBytes(bytes);

    expect(book.tables.keys, unorderedEquals(['Records', 'Customers', 'Nurses', 'Services', 'Areas']));
    final records = book.tables['Records']!;
    final header = records.rows.first.map((c) => c?.value.toString()).toList();
    expect(header, ExportLabels.english.recordHeaders);
    expect(records.rows.first.first!.cellStyle!.isBold, isTrue);

    // Each record row carries the customer details next to the service data.
    final first = records.rows[1].map((c) => c?.value).toList();
    expect(first[1].toString(), 'Ahmed Mohamed');
    expect(first[2].toString(), '01012345678');
    expect(first[3].toString(), 'Street 1');
    expect(first[4].toString(), 'Smouha');
    expect(first[6].toString(), 'Sara Ahmed');
    expect(first[7].toString(), 'Home Nursing Visit');
    expect((first[8]! as xl.IntCellValue).value, 500);
    expect(first[9].toString(), 'Cash');
    expect(first[10], isA<xl.DateCellValue>());
    expect(first[11], isA<xl.TimeCellValue>());

    // 3 records + header + totals row with a SUM formula.
    expect(records.rows, hasLength(5));
    expect(records.rows.last[8]!.value, isA<xl.FormulaCellValue>());

    final services = book.tables['Services']!.rows.map((r) => r.map((c) => c?.value.toString()).toList()).toList();
    expect(services[2][2], 'Variable');
    final nurses = book.tables['Nurses']!.rows.map((r) => r.map((c) => c?.value.toString()).toList()).toList();
    expect(nurses[2][3], 'Inactive');
  });

  test('only the requested sheets are written', () {
    final bytes = codec.encodeExport(data, ExportLabels.english, {ExportSheet.customers}).valueOrNull!;
    expect(xl.Excel.decodeBytes(bytes).tables.keys, ['Customers']);
  });

  test('an exported workbook can be imported back (round trip)', () {
    final bytes = codec.encodeExport(data, ExportLabels.english, {...ExportSheet.values}).valueOrNull!;
    final opened = const OpenWorkbook(codec)(fileName: 'export.xlsx', bytes: bytes).valueOrNull!;

    expect(opened.bestSheet!.name, 'Records');
    final mapping = opened.mappings['Records']!;
    expect(
      mapping.columns.keys,
      containsAll([ImportField.customerName, ImportField.phone, ImportField.paymentMethod, ImportField.patientName]),
    );

    final plan = const ImportPlanner(unspecifiedLabel: 'Unspecified').plan(opened.bestSheet!, mapping);
    expect(plan.skipped, isEmpty, reason: 'the totals row is not a record');
    expect(plan.records, hasLength(3));
    expect(plan.customers, hasLength(2));
    expect(plan.totalRevenue, Money.pounds(825));
    final second = plan.records.firstWhere((r) => r.legacyRef == 'r2');
    expect(second.paymentMethod, PaymentMethod.electronic);
    expect(second.patientName, 'His mother');
    expect(second.serviceTime, const LocalTime(19, 30));
    expect(second.notes, 'Follow-up');
    expect(plan.records.firstWhere((r) => r.legacyRef == 'r3').paymentMethod, PaymentMethod.unspecified);
  });

  test('Arabic export is right-to-left and uses Arabic labels', () {
    const arabic = ExportLabels(
      rtl: true,
      sheetNames: {ExportSheet.records: 'السجلات'},
      recordHeaders: [
        'رقم السجل', 'اسم العميل', 'هاتف العميل', 'عنوان العميل', 'منطقة العميل', 'المريض (إن اختلف)', 'الممرض',
        'الخدمة', 'السعر (ج.م)', 'طريقة الدفع', 'تاريخ الخدمة', 'وقت الخدمة', 'ملاحظات', 'تاريخ الإنشاء', //
      ],
      customerHeaders: [],
      nurseHeaders: [],
      serviceHeaders: [],
      areaHeaders: [],
      paymentLabels: {
        PaymentMethod.cash: 'نقدي',
        PaymentMethod.electronic: 'إلكتروني',
        PaymentMethod.unspecified: 'غير مسجل',
      },
      active: 'نشط',
      inactive: 'غير نشط',
      variablePrice: 'متغير',
      total: 'الإجمالي',
    );
    final bytes = codec.encodeExport(data, arabic, {ExportSheet.records}).valueOrNull!;
    final sheet = xl.Excel.decodeBytes(bytes).tables['السجلات']!;
    expect(sheet.isRTL, isTrue);
    expect(sheet.rows.first.first!.cellStyle!.isBold, isTrue, reason: 'styles survive the RTL pass');
    expect(sheet.rows[1][9]!.value.toString(), 'نقدي');

    // …and the Arabic headers are recognised on import too.
    final opened = const OpenWorkbook(codec)(fileName: 'ar.xlsx', bytes: bytes).valueOrNull!;
    final plan = const ImportPlanner(unspecifiedLabel: 'غير محدد').plan(opened.bestSheet!, opened.mappings['السجلات']!);
    expect(plan.records, hasLength(3));
    expect(plan.records.first.paymentMethod, PaymentMethod.cash);
  });

  test('a file that is not a workbook is reported as unreadable', () {
    final result = const OpenWorkbook(codec)(fileName: 'notes.xlsx', bytes: Uint8List.fromList([1, 2, 3, 4]));
    expect(result.failureOrNull, const FileFailure(FileFailureReason.unreadable));
    expect(
      const OpenWorkbook(codec)(fileName: 'empty.xlsx', bytes: Uint8List(0)).failureOrNull,
      const FileFailure(FileFailureReason.empty),
    );
  });

  test('ExportWorkbook passes the date range and names the file', () async {
    final repo = _Repo();
    final export = ExportWorkbook(repo, codec, clock: () => DateTime(2026, 10, 4));
    final result = await export(
      ExportRequest(from: DateTime(2026, 9), to: DateTime(2026, 9, 30), sheets: const {ExportSheet.records}),
      ExportLabels.english,
    );
    final file = result.valueOrNull!;
    expect(file.fileName, 'sanad-export-2026-10-04.xlsx');
    expect(file.recordCount, 3);
    expect(repo.request!.from, DateTime(2026, 9));

    final invalid = await export(
      ExportRequest(from: DateTime(2026, 9, 30), to: DateTime(2026, 9)),
      ExportLabels.english,
    );
    expect(invalid.failureOrNull, isA<ValidationFailure>());
  });

  test('ImportPlan payload converts values to database formats', () {
    final opened = const OpenWorkbook(codec)(
      fileName: 'export.xlsx',
      bytes: codec.encodeExport(data, ExportLabels.english, {ExportSheet.records}).valueOrNull!,
    ).valueOrNull!;
    final plan = const ImportPlanner(unspecifiedLabel: 'Unspecified')
        .plan(opened.bestSheet!, opened.mappings['Records']!);
    final payload = plan.toPayload(fileName: 'export.xlsx', fileSha256: opened.sha256);
    final first = (payload['records']! as List).cast<Map<String, Object?>>().firstWhere((r) => r['legacy_ref'] == 'r1');
    expect(first['service_date'], '2026-09-12');
    expect(first['service_time'], '19:30:00');
    expect(first['price'], 500);
    expect(first['payment_method'], 'cash');
    expect(opened.sha256, hasLength(64));
  });

  test('reads workbooks written by other tools (absolute part names)', () {
    // Synthetic file in the legacy layout, written with openpyxl (no real data).
    final bytes = File('test/fixtures/legacy_synthetic_openpyxl.xlsx').readAsBytesSync();
    final opened = const OpenWorkbook(codec)(fileName: 'legacy.xlsx', bytes: bytes).valueOrNull!;
    expect(opened.bestSheet!.name, 'سجل الزيارات');
    final plan = const ImportPlanner(unspecifiedLabel: 'غير محدد')
        .plan(opened.bestSheet!, opened.mappings['سجل الزيارات']!);
    expect(plan.records, hasLength(5));
    expect(plan.skipped.single.issues, ['date_missing']);
    expect(plan.records.first.serviceDate, DateTime(2026, 10, 1), reason: 'real Excel date cells');
    expect(plan.customers.where((c) => c.phone == '01155555501').single.otherNames, ['والدة منى']);
    expect(plan.nurses.where((n) => n.name.contains('سارة')).single.rowCount, 2, reason: 'أحمد / احمد merged');
  });
}
