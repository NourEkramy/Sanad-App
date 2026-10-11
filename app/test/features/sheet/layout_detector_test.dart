import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/excel/domain/entities/sheet_table.dart';
import 'package:sanad/features/excel/domain/import/column_mapping.dart';
import 'package:sanad/features/sheet/domain/layout_detector.dart';
import 'package:sanad/features/sheet/domain/sheet_link.dart';
import 'package:sanad/features/sheet/domain/sheet_sync.dart';

SheetTable table(String name, List<List<Object?>> rows) => SheetTable(
  name: name,
  rows: [
    for (final row in rows) [for (final v in row) SheetCell(v)],
  ],
);

/// The original workbook's sheets as read through the connector (fictional
/// data): a dashboard, the visits log with pre-numbered empty rows, the
/// customers sheet and the drop-down lists.
SheetSnapshot legacyWorkbook() => SheetSnapshot(
  title: 'سند',
  contentHash: 'hash',
  tables: [
    table('لوحة التحكم', [
      ['لوحة التحكم'],
      ['إجمالي الإيراد', 1200],
      ['عدد الزيارات', 3],
    ]),
    table('سجل الزيارات', [
      ['سند للرعاية المنزلية  |  سجل الزيارات الميدانية'],
      ['أدخل بيانات كل زيارة في صف جديد'],
      [
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
      ],
      [
        1,
        DateTime(2026, 6, 20),
        'Saturday',
        '9م',
        'عميل أول',
        '01011111111',
        'شارع 1',
        'سموحة',
        'ممرض أول',
        'حقن عضل',
        75,
        'تم الاستلام',
        null,
        '2026-06',
      ],
      [
        2,
        DateTime(2026, 6, 23),
        'Tuesday',
        '6م',
        'عميل ثان',
        '01022222222',
        null,
        'العجمي',
        'ممرض أول',
        'غيار عادي',
        120,
        'تم الاستلام',
        null,
        '2026-06',
      ],
      // Pre-numbered rows waiting for data (their formulas show nothing).
      [3],
      [4],
    ]),
    table('بيانات الحالات', [
      ['بيانات الحالات'],
      [null],
      ['م', 'اسم المريض / الحالة', 'رقم التليفون', 'العنوان التفصيلي', 'المنطقة'],
      [1, 'عميل أول', '01011111111', 'شارع 1', 'سموحة'],
      [2, 'عميل بدون رقم', null, null, null],
      [3, 'عميل برقم خطأ', '12345', null, null],
      [4, 'عميل ثالث', '١٠٣٣٣٣٣٣٣٣', null, 'العجمي'],
    ]),
    table('قوائم', [
      ['الخدمات', 'السعر', 'الممرضين', 'المناطق'],
      ['حقن عضل', 75, 'ممرض أول', 'سموحة'],
      ['صيدلية', '**', 'ممرض ثان', 'العجمي'],
      ['غيار عادي', 120, null, null],
    ]),
  ],
);

void main() {
  const detector = SheetLayoutDetector();

  test('finds the visits log of the original workbook below its title rows', () {
    final found = detector.detect(legacyWorkbook());
    final visits = found.layout.visits;
    expect(visits.sheet, 'سجل الزيارات');
    expect(visits.headerRow, 3);
    expect(visits.headers, {
      ImportField.legacyRef: 'م',
      ImportField.serviceDate: 'تاريخ الزيارة',
      ImportField.serviceTime: 'وقت الزيارة',
      ImportField.customerName: 'اسم المريض / الحالة',
      ImportField.phone: 'رقم التليفون',
      ImportField.address: 'العنوان التفصيلي',
      ImportField.area: 'المنطقة',
      ImportField.nurse: 'اسم الممرض / الفني',
      ImportField.service: 'الخدمة المُقدَّمة',
      ImportField.price: 'ثمن الزيارة (ج.م)',
      ImportField.status: 'حالة الاستلام',
      ImportField.notes: 'ملاحظات',
      ImportField.paymentMethod: paymentHeader,
    });
    expect(visits.weekdayHeader, 'اليوم');
    expect(visits.monthHeader, 'الشهر (تلقائي)');
    expect(visits.create, isEmpty, reason: 'the sheet exists');
    expect(found.visitsTable?.name, 'سجل الزيارات');
    expect(found.visitRows, 2, reason: 'pre-numbered empty rows are not visits');
  });

  test('finds the customers sheet and the lists, and what they contain', () {
    final found = detector.detect(legacyWorkbook());
    expect(
      found.layout.cases,
      const CasesLayout(
        sheet: 'بيانات الحالات',
        headerRow: 3,
        name: 'اسم المريض / الحالة',
        phone: 'رقم التليفون',
        address: 'العنوان التفصيلي',
        area: 'المنطقة',
      ),
    );
    expect(
      found.layout.lists,
      const ListsLayout(
        sheet: 'قوائم',
        headerRow: 1,
        services: 'الخدمات',
        price: 'السعر',
        nurses: 'الممرضين',
        areas: 'المناطق',
      ),
    );
    expect(found.extras.customers, [
      ('عميل أول', '01011111111', 'شارع 1', 'سموحة'),
      ('عميل ثالث', '01033333333', null, 'العجمي'),
    ], reason: 'customers without a valid phone stay in the sheet only');
    expect(found.extras.services, [('حقن عضل', Money.pounds(75)), ('صيدلية', null), ('غيار عادي', Money.pounds(120))]);
    expect(found.extras.hasServicePrices, isTrue);
    expect(found.extras.nurses, ['ممرض أول', 'ممرض ثان']);
    expect(found.extras.areas, ['سموحة', 'العجمي']);
  });

  test('an empty spreadsheet gets Sanad\'s own sheets', () {
    final found = detector.detect(SheetSnapshot(title: 'New', contentHash: 'h', tables: [table('Sheet1', const [])]));
    expect(found.layout.visits, VisitsLayout.standard());
    expect(found.layout.cases, CasesLayout.standard());
    expect(found.layout.lists, ListsLayout.standard());
    expect(found.layout.visits.create, contains(sanadIdHeader));
    expect(found.visitsTable, isNull);
    expect(found.visitRows, 0);
    expect(found.extras, const SheetExtras());
  });

  test('the layout is remembered as JSON', () {
    final layout = detector.detect(legacyWorkbook()).layout;
    expect(SheetLayout.fromJson(layout.toJson()), layout);
    final standard = SheetLayout(
      visits: VisitsLayout.standard(),
      cases: CasesLayout.standard(),
      lists: ListsLayout.standard(),
    );
    expect(SheetLayout.fromJson(standard.toJson()), standard);
  });
}
