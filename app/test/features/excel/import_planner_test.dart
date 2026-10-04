import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/core/utils/text_normalizer.dart';
import 'package:sanad/features/excel/domain/entities/sheet_table.dart';
import 'package:sanad/features/excel/domain/import/column_mapping.dart';
import 'package:sanad/features/excel/domain/import/import_plan.dart';
import 'package:sanad/features/excel/domain/import/import_planner.dart';
import 'package:sanad/features/excel/domain/import/value_parsers.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';

/// A synthetic copy of the legacy "سجل الزيارات" sheet: same title rows,
/// same Arabic headers, and one row for each data problem found in the real
/// workbook (no real customer data).
SheetTable legacySheet() {
  List<SheetCell> row(List<Object?> values) => [for (final v in values) SheetCell(v)];
  const headers = [
    'م',
    'تاريخ الزيارة',
    'اليوم',
    'وقت الزيارة',
    'اسم المريض / الحالة',
    'رقم التليفون',
    'العنوان التفصيلي',
    'المنطقة',
    'اسم الممرض / الفني',
    'الخدمة المُقدَّمة',
    'ثمن الزيارة (ج.م)',
    'حالة الاستلام',
    'ملاحظات',
    'الشهر (تلقائي)',
  ];
  return SheetTable(
    name: 'سجل الزيارات',
    rows: [
      row(['سند للرعاية المنزلية  |  سجل الزيارات الميدانية']),
      row(['أدخل بيانات كل زيارة في صف جديد']),
      row(headers),
      // 4: normal visit (customer already in the database)
      row([
        1,
        '2026-06-20',
        'Saturday',
        '9م',
        'عميل أول',
        '01011111111',
        'شارع 1',
        'الهانوفيل',
        'عبده',
        'غيار عادى',
        '120 ج.م',
        'تم الاستلام',
        null,
        '2026-06',
      ]),
      // 5: same customer, later visit in another area → latest area wins
      row([
        2,
        '2026-06-23',
        'Tuesday',
        '6م',
        'عميل أول',
        '01011111111',
        'شارع 2',
        'أكتوبر',
        'يوسف',
        'غيار عادي',
        '115 ج.م',
        'تم الاستلام',
        'تانى مرة',
        '2026-06',
      ]),
      // 6: same phone, different person (family member)
      row([
        3,
        '2026-06-24',
        'Wednesday',
        '8م',
        'قريب العميل',
        '01011111111',
        'شارع 2',
        'أكتوبر',
        'يوسف',
        'حقن عضل',
        '75 ج.م',
        'تم الاستلام',
        null,
        '2026-06',
      ]),
      // 7: placeholder phone → needs review
      row([
        4,
        '2026-06-18',
        'Thursday',
        '**',
        'حالة تبع المركز',
        '0',
        '**',
        'أكتوبر',
        'سلطان',
        'صيدلية',
        '20 ج.م',
        'تم الاستلام',
        'ملاحظة',
        '2026-06',
      ]),
      // 8: price typed as text
      row([
        5,
        '2026-08-01',
        'Saturday',
        '1م',
        'عميل تاني',
        '01222222222',
        'شارع 3',
        'البيطاش',
        'أسماء منصور',
        'تركيب كانيولا  + محلول',
        '45ج',
        'تم الاستلام',
        null,
        '2026-08',
      ]),
      // 9: time without AM/PM, nurse spelled without hamza
      row([
        6,
        '2026-08-02',
        'Sunday',
        '11.3',
        'عميل تاني',
        '01222222222',
        'شارع 3',
        'البيطاش',
        'اسماء منصور',
        'تركيب كانيولا + محلول',
        '150 ج.م',
        'تم الاستلام',
        null,
        '2026-08',
      ]),
      // 10: no service
      row([
        7,
        '2026-08-03',
        'Monday',
        '2.30ص',
        'عميل تالت',
        '01555555555',
        null,
        'البيطاش',
        'سلطان',
        null,
        '0 ج.م',
        'تم الاستلام',
        null,
        '2026-08',
      ]),
      // 11: missing date → skipped
      row([
        8,
        null,
        null,
        '5م',
        'بدون تاريخ',
        '01000000000',
        null,
        'أكتوبر',
        'سلطان',
        'حقن عضل',
        '75 ج.م',
        'تم الاستلام',
        null,
        null,
      ]),
      // 12-13: template rows with only the running number
      row([9]),
      row([10, null, null, null, null, null, null, null, null, null, null, null, null, null]),
    ],
  );
}

void main() {
  const detector = ColumnDetector();
  const planner = ImportPlanner(unspecifiedLabel: 'غير محدد');

  test('detects the header row and maps every legacy column', () {
    final mapping = detector.detect(legacySheet())!;
    expect(mapping.headerRow, 2, reason: 'row 3 in Excel');
    expect(mapping.columns, {
      ImportField.legacyRef: 0,
      ImportField.serviceDate: 1,
      ImportField.serviceTime: 3,
      ImportField.customerName: 4,
      ImportField.phone: 5,
      ImportField.address: 6,
      ImportField.area: 7,
      ImportField.nurse: 8,
      ImportField.service: 9,
      ImportField.price: 10,
      ImportField.status: 11,
      ImportField.notes: 12,
    });
    expect(mapping.isUsable, isTrue);
  });

  group('plan', () {
    late ImportPlan plan;

    setUp(() {
      final sheet = legacySheet();
      plan = planner.plan(
        sheet,
        detector.detect(sheet)!,
        existing: ExistingData(phones: {'01011111111'}, areaKeys: {TextNormalizer.key('الهانوفيل')}),
      );
    });

    test('imports valid rows, skips only unusable ones, ignores template rows', () {
      expect(plan.records, hasLength(7));
      expect(plan.skipped.single.rowNumber, 11);
      expect(plan.skipped.single.issues, [ImportIssue.dateMissing]);
      expect(plan.rowCount, 8);
    });

    test('identifies customers by phone and never duplicates them', () {
      expect(plan.customers, hasLength(4));
      final first = plan.customers.firstWhere((c) => c.phone == '01011111111');
      expect(first.rowCount, 3);
      expect(first.fullName, 'عميل أول', reason: 'most frequent name wins');
      expect(first.otherNames, ['قريب العميل']);
      expect(first.exists, isTrue, reason: 'matched to the existing customer');
      expect(first.areaKey, TextNormalizer.key('أكتوبر'), reason: 'latest visit area');
      expect(first.address, 'شارع 2');
      expect(plan.newCustomers, 3);
      expect(plan.matchedCustomers, 1);
    });

    test('family members sharing a phone are kept as the patient name', () {
      final record = plan.records.firstWhere((r) => r.rowNumber == 6);
      expect(record.patientName, 'قريب العميل');
      expect(record.warnings, contains(ImportIssue.phoneShared));
    });

    test('each record keeps the address and area written on its own row', () {
      final firstVisit = plan.records.firstWhere((r) => r.rowNumber == 4);
      expect(firstVisit.address, 'شارع 1');
      expect(firstVisit.areaName, 'الهانوفيل');
      expect(firstVisit.warnings, contains(ImportIssue.customerDetailsChanged));
    });

    test('placeholder phones create a customer flagged for review', () {
      final review = plan.customers.singleWhere((c) => c.needsReview);
      expect(review.phone, isNull);
      expect(review.fullName, 'حالة تبع المركز');
      final record = plan.records.firstWhere((r) => r.rowNumber == 7);
      expect(record.warnings, containsAll([ImportIssue.phoneInvalid, ImportIssue.timeMissing]));
      expect(record.serviceTime, isNull);
      expect(record.address, isNull, reason: '"**" is a placeholder, not an address');
    });

    test('prices: text is cleaned, zero is allowed, totals add up', () {
      expect(plan.records.firstWhere((r) => r.rowNumber == 8).price, Money.pounds(45));
      expect(plan.records.firstWhere((r) => r.rowNumber == 8).warnings, contains(ImportIssue.priceCleaned));
      expect(plan.records.firstWhere((r) => r.rowNumber == 10).price, Money.zero);
      expect(plan.totalRevenue, Money.pounds(120 + 115 + 75 + 20 + 45 + 150 + 0));
    });

    test('times are parsed, ambiguous ones are not guessed', () {
      expect(plan.records.firstWhere((r) => r.rowNumber == 4).serviceTime, const LocalTime(21, 0));
      expect(plan.records.firstWhere((r) => r.rowNumber == 10).serviceTime, const LocalTime(2, 30));
      final ambiguous = plan.records.firstWhere((r) => r.rowNumber == 9);
      expect(ambiguous.serviceTime, isNull);
      expect(ambiguous.warnings, contains(ImportIssue.timeAmbiguous));
    });

    test('spelling variants collapse into one nurse / service / area', () {
      expect(plan.nurses.map((n) => n.name), unorderedEquals(['عبده', 'يوسف', 'سلطان', 'أسماء منصور']));
      expect(plan.nurses.firstWhere((n) => n.name == 'أسماء منصور').rowCount, 2);
      expect(plan.services.where((s) => s.key == TextNormalizer.key('غيار عادى')).single.rowCount, 2);
      expect(plan.services.where((s) => s.key == TextNormalizer.key('تركيب كانيولا + محلول')).single.rowCount, 2);
      expect(plan.areas.firstWhere((a) => a.name == 'الهانوفيل').exists, isTrue);
      expect(plan.newAreas, 2);
    });

    test('a missing service becomes an explicit "unspecified" entry', () {
      expect(plan.records.firstWhere((r) => r.rowNumber == 10).warnings, contains(ImportIssue.serviceMissing));
      expect(plan.services.map((s) => s.name), contains('غير محدد'));
    });

    test('no payment column → every record is marked unspecified', () {
      expect(plan.records.every((r) => r.paymentMethod == PaymentMethod.unspecified), isTrue);
      expect(plan.recordsWithoutPayment, 7);
    });

    test('the original row is kept for the audit trail', () {
      final raw = plan.records.firstWhere((r) => r.rowNumber == 4).raw;
      expect(raw['حالة الاستلام'], 'تم الاستلام');
      expect(raw['م'], '1');
      expect(plan.records.firstWhere((r) => r.rowNumber == 4).legacyRef, '1');
    });

    test('payload references are consistent (every key resolves)', () {
      final payload = plan.toPayload(fileName: 'sanad.xlsx', fileSha256: 'abc');
      Set<String> keys(String name) => {for (final e in payload[name]! as List) (e as Map)['key'] as String};
      final customers = keys('customers'), nurses = keys('nurses'), services = keys('services'), areas = keys('areas');
      for (final r in (payload['records']! as List).cast<Map<String, Object?>>()) {
        expect(customers, contains(r['customer_key']));
        expect(nurses, contains(r['nurse_key']));
        expect(services, contains(r['service_key']));
        expect(areas, contains(r['area_key']));
        expect(r['payment_method'], 'unspecified');
      }
      for (final c in (payload['customers']! as List).cast<Map<String, Object?>>()) {
        expect(areas, contains(c['area_key']));
      }
      expect((payload['skipped']! as List), hasLength(1));
      expect(((payload['summary']! as Map)['revenue']), 525);
    });
  });

  test('a sheet without dates or customers is not usable', () {
    final sheet = SheetTable(
      name: 'Expenses',
      rows: [
        [
          for (final h in ['البند', 'المبلغ']) SheetCell(h),
        ],
      ],
    );
    expect(detector.detect(sheet), isNull);
  });
}
