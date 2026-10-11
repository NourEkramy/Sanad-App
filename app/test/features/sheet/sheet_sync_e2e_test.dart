import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sanad/core/database/sanad_database.dart';
import 'package:sanad/core/storage/secure_store.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/areas/data/local_area_repository.dart';
import 'package:sanad/features/care_services/data/local_care_service_repository.dart';
import 'package:sanad/features/customers/data/local_customer_repository.dart';
import 'package:sanad/features/customers/domain/entities/customer.dart';
import 'package:sanad/features/excel/data/local_excel_repositories.dart';
import 'package:sanad/features/nurses/data/local_nurse_repository.dart';
import 'package:sanad/features/records/data/local_record_repository.dart';
import 'package:sanad/features/records/domain/entities/record_draft.dart';
import 'package:sanad/features/records/domain/entities/record_filter.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';
import 'package:sanad/features/records/domain/usecases/record_usecases.dart';
import 'package:sanad/features/sheet/data/apps_script_connector.dart';
import 'package:sanad/features/sheet/data/local_sheet_store.dart';
import 'package:sanad/features/sheet/domain/sheet_link.dart';
import 'package:sanad/features/sheet/domain/sheet_usecases.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/database.dart';

/// End to end: the app's sheet code, over real HTTP, against the real
/// connector script (`tools/google-sheets/Code.gs`) running in Node on an
/// in-memory copy of the original workbook's layout (fictional data).

const _month = '=IF(B{r}="","",TEXT(B{r},"yyyy-mm"))';
const _day = '=IF(B{r}="","",TEXT(B{r},"dddd"))';

List<Object?> visit(int r, List<Object?> values) => [
  r - 3,
  if (values.isEmpty) '' else values[0],
  _day.replaceAll('{r}', '$r'),
  ...values.skip(1).take(10),
  if (values.isEmpty) ...List.filled(10, ''),
  _month.replaceAll('{r}', '$r'),
];

Map<String, Object?> workbook() => {
  'title': 'سند (تجربة)',
  'sheets': [
    {
      'name': 'لوحة التحكم',
      'rows': [
        ['لوحة التحكم'],
        ['إجمالي الإيراد', "=SUM('سجل الزيارات'!K4:K564)"],
      ],
    },
    {
      'name': 'سجل الزيارات',
      'rows': [
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
        visit(4, [
          {'d': '2026-06-20'},
          '9م',
          'عميل أول',
          '01011111111',
          'شارع 1',
          'سموحة',
          'ممرض أول',
          'حقن عضل',
          80,
          'تم الاستلام',
          '',
        ]),
        visit(5, [
          {'d': '2026-06-23'},
          '6م',
          'عميل ثان',
          '01022222222',
          '',
          'العجمي',
          'ممرض ثان',
          'غيار عادي',
          120,
          'تم الاستلام',
          'ملاحظة',
        ]),
        // Pre-numbered rows with formulas, waiting for data.
        visit(6, const []),
        visit(7, const []),
      ],
    },
    {
      'name': 'بيانات الحالات',
      'rows': [
        ['بيانات الحالات'],
        [''],
        ['م', 'اسم المريض / الحالة', 'رقم التليفون', 'العنوان التفصيلي', 'المنطقة'],
        [1, 'عميل أول', '01011111111', 'شارع 1', 'سموحة'],
        [2, 'عميل بدون رقم', '', '', ''],
      ],
    },
    {
      'name': 'قوائم',
      'rows': [
        ['الخدمات', 'السعر', 'الممرضين', 'المناطق'],
        ['حقن عضل', 80, 'ممرض أول', 'سموحة'],
        ['غيار عادي', 120, 'ممرض ثان', 'العجمي'],
        ['صيدلية', '**', '', ''],
      ],
    },
  ],
};

/// The spreadsheet as the connector holds it (dates as yyyy-MM-dd, formulas
/// as "=…").
class Book {
  Book(List<Object?> json)
    : sheets = {
        for (final s in json.cast<Map<String, Object?>>())
          s['name']! as String: [for (final row in (s['rows']! as List).cast<List<Object?>>()) row],
      };

  final Map<String, List<List<Object?>>> sheets;

  /// Row [row] (1-based) of [sheet] as header → value.
  Map<String, Object?> row(String sheet, int row, {int headerRow = 1}) {
    final rows = sheets[sheet]!;
    final headers = rows[headerRow - 1];
    final values = row - 1 < rows.length ? rows[row - 1] : const [];
    return {
      for (var c = 0; c < headers.length; c++)
        if ('${headers[c]}'.isNotEmpty) '${headers[c]}': c < values.length ? values[c] : '',
    };
  }

  List<Object?> column(String sheet, String header, {int headerRow = 1}) {
    final rows = sheets[sheet]!;
    final c = rows[headerRow - 1].indexOf(header);
    return [for (final r in rows.skip(headerRow)) c < r.length ? r[c] : ''];
  }
}

bool _hasNode() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

void main() {
  late Process server;
  late Uri url;
  late SanadDatabase db;
  late LocalSheetStore store;
  late LocalImportRepository imports;
  late SheetLinkStore links;
  late ConnectSheet connect;
  late LinkSheet linkSheet;
  late SyncSheet sync;
  late LocalRecordRepository records;
  late LocalCustomerRepository customers;
  final client = http.Client();
  var tick = 0;
  DateTime clock() => DateTime(2026, 10, 11, 12).add(Duration(milliseconds: tick++));

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('sanad_sheet');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/workbook.json')..writeAsStringSync(jsonEncode(workbook()));
    server = await Process.start('node', ['../tools/google-sheets/dev-server.js', file.path, '0']);
    addTearDown(server.kill);
    unawaited(server.stderr.drain<void>());
    final first = await server.stdout.transform(utf8.decoder).transform(const LineSplitter()).first;
    url = Uri.parse(RegExp(r'http://\S+/exec').firstMatch(first)!.group(0)!);

    db = await openTestDatabase(clock: clock);
    addTearDown(db.close);
    store = LocalSheetStore(db);
    imports = LocalImportRepository(db);
    links = SheetLinkStore(MemoryStore());
    final connector = AppsScriptConnector(client: client);
    connect = ConnectSheet(connector, store, imports);
    linkSheet = LinkSheet(store, imports, links, clock: clock);
    sync = SyncSheet(connector, store, links, clock: clock);
    records = LocalRecordRepository(db);
    customers = LocalCustomerRepository(db);
  });

  Future<Book> book() async {
    final response = await client.get(url.replace(path: '/state'));
    return Book(jsonDecode(utf8.decode(response.bodyBytes)) as List<Object?>);
  }

  Future<void> connectAndLoad({bool replace = false}) async {
    final connection = (await connect(
      url.toString(),
      code: (await links.read())?.key,
      unspecifiedLabel: 'غير محدد',
    )).valueOrNull!;
    final loaded = await linkSheet.load(connection, replace: replace, unspecifiedLabel: 'غير محدد');
    expect(loaded.failureOrNull, isNull);
  }

  Future<void> syncAll() async {
    final result = await sync();
    expect(result.failureOrNull, isNull);
    expect((await store.pendingCount()).valueOrNull, 0);
  }

  Future<ServiceRecord> addVisit(Customer customer) async {
    final nurse = (await LocalNurseRepository(db).getNurses()).valueOrNull!.firstWhere((n) => n.name == 'ممرض أول');
    final service = (await LocalCareServiceRepository(
      db,
    ).getServices()).valueOrNull!.firstWhere((s) => s.name == 'حقن عضل');
    return (await AddServiceRecord(records, const Uuid().v4, clock: clock)(
      customer,
      RecordDraft(
        nurseId: nurse.id,
        serviceId: service.id,
        price: '150',
        paymentMethod: PaymentMethod.electronic,
        serviceDate: DateTime(2026, 10, 5),
        serviceTime: const LocalTime(19, 30),
      ),
    )).valueOrNull!;
  }

  group('with the connector script', skip: _hasNode() ? false : 'Node.js is needed to run the script', () {
    test('connect, load everything, then every change reaches the sheet', () async {
      // Connecting reads the whole spreadsheet.
      final connection = (await connect(url.toString(), unspecifiedLabel: 'غير محدد')).valueOrNull!;
      expect(connection.pairing.title, 'سند (تجربة)');
      expect(connection.plan!.records, hasLength(2), reason: 'pre-numbered empty rows are not visits');
      expect(connection.sheetHasData, isTrue);
      expect(connection.phoneHasData, isFalse);
      expect(connection.detected.layout.visits.headerRow, 3);

      // Loading puts the sheet's data on the phone.
      expect((await linkSheet.load(connection, replace: false, unspecifiedLabel: 'غير محدد')).failureOrNull, isNull);
      expect((await records.list(const RecordFilter())).valueOrNull, hasLength(2));
      expect((await customers.list()).valueOrNull!.map((c) => c.fullName), containsAll(['عميل أول', 'عميل ثان']));
      final injection = (await LocalCareServiceRepository(
        db,
      ).getServices()).valueOrNull!.firstWhere((s) => s.name == 'حقن عضل');
      expect(injection.defaultPrice, Money.pounds(80), reason: "the sheet's price replaces the built-in one");

      // The first update only adds Sanad's IDs (and what the sheet lacks).
      await syncAll();
      var sheet = await book();
      final loaded = (await records.list(const RecordFilter())).valueOrNull!;
      final first = sheet.row('سجل الزيارات', 4, headerRow: 3);
      expect(first[sanadIdHeader], loaded.firstWhere((r) => r.customerName == 'عميل أول').id);
      expect(first['ثمن الزيارة (ج.م)'], 80, reason: 'loaded rows are not rewritten');
      expect(first['اليوم'], '=IF(B4="","",TEXT(B4,"dddd"))');
      expect(sheet.sheets['سجل الزيارات']![2].sublist(14), [paymentHeader, sanadIdHeader]);
      expect(sheet.row('سجل الزيارات', 6, headerRow: 3)[sanadIdHeader], '', reason: 'template rows untouched');
      expect(sheet.column('قوائم', 'الخدمات').where((s) => s == 'حقن عضل'), hasLength(1));
      expect(sheet.row('قوائم', 2)['السعر'], 80, reason: 'the built-in price did not overwrite the sheet');
      final cases = sheet.column('بيانات الحالات', 'اسم المريض / الحالة', headerRow: 3);
      expect(cases.where((n) => n != ''), ['عميل أول', 'عميل بدون رقم', 'عميل ثان']);

      // A new visit goes into the first free pre-numbered row.
      final area = (await LocalAreaRepository(db).getAreas()).valueOrNull!.firstWhere((a) => a.name == 'سموحة');
      final newcomer = (await customers.create(
        fullName: 'عميل جديد',
        phone: '01033333333',
        areaId: area.id,
        address: 'شارع 3',
      )).valueOrNull!;
      final added = await addVisit(newcomer);
      await syncAll();
      sheet = await book();
      expect(sheet.row('سجل الزيارات', 6, headerRow: 3), {
        'م': 3,
        'تاريخ الزيارة': '2026-10-05',
        'اليوم': '=IF(B6="","",TEXT(B6,"dddd"))',
        'وقت الزيارة': '7:30م',
        'اسم المريض / الحالة': 'عميل جديد',
        'رقم التليفون': '01033333333',
        'العنوان التفصيلي': 'شارع 3',
        'المنطقة': 'سموحة',
        'اسم الممرض / الفني': 'ممرض أول',
        'الخدمة المُقدَّمة': 'حقن عضل',
        'ثمن الزيارة (ج.م)': 150,
        'حالة الاستلام': 'تم الاستلام',
        'ملاحظات': '',
        'الشهر (تلقائي)': '=IF(B6="","",TEXT(B6,"yyyy-mm"))',
        paymentHeader: 'إلكتروني',
        sanadIdHeader: added.id,
      });
      expect(sheet.row('بيانات الحالات', 7, headerRow: 3)['اسم المريض / الحالة'], 'عميل جديد');

      // Corrections rewrite the same row.
      final fixed = await UpdateServiceRecord(records, clock: clock)(
        added.id,
        RecordDraft(
          nurseId: added.nurseId,
          serviceId: added.serviceId,
          price: '175',
          paymentMethod: added.paymentMethod,
          serviceDate: added.serviceDate,
          serviceTime: added.serviceTime,
        ),
      );
      expect(fixed.failureOrNull, isNull);
      await syncAll();
      sheet = await book();
      expect(sheet.row('سجل الزيارات', 6, headerRow: 3)['ثمن الزيارة (ج.م)'], 175);
      expect(sheet.row('سجل الزيارات', 7, headerRow: 3)[sanadIdHeader], '');

      // Deleting clears the row's data and keeps its number and formulas.
      await records.archive(added.id);
      await syncAll();
      sheet = await book();
      final cleared = sheet.row('سجل الزيارات', 6, headerRow: 3);
      expect(cleared['م'], 3);
      expect(cleared['اليوم'], startsWith('=IF('));
      expect(cleared['تاريخ الزيارة'], '');
      expect(cleared['اسم المريض / الحالة'], '');
      expect(cleared[sanadIdHeader], '');

      // New list entries are added to their column.
      await LocalNurseRepository(db).createNurse(name: 'ممرض ثالث');
      await syncAll();
      sheet = await book();
      expect(sheet.column('قوائم', 'الممرضين').where((n) => n != ''), ['ممرض أول', 'ممرض ثان', 'ممرض ثالث']);
    });

    test('loading again replaces the phone data with the sheet, keeping the same IDs', () async {
      await connectAndLoad();
      await syncAll();
      final area = (await LocalAreaRepository(db).getAreas()).valueOrNull!.firstWhere((a) => a.name == 'سموحة');
      final newcomer = (await customers.create(
        fullName: 'عميل جديد',
        phone: '01033333333',
        areaId: area.id,
      )).valueOrNull!;
      final added = await addVisit(newcomer);
      await syncAll();
      final before = await book();

      await connectAndLoad(replace: true);
      final ids = (await records.list(const RecordFilter())).valueOrNull!.map((r) => r.id);
      expect(ids, hasLength(3));
      expect(ids, contains(added.id), reason: 'the row carries its Sanad ID');
      expect((await customers.findByPhone('01033333333')).valueOrNull?.fullName, 'عميل جديد');

      await syncAll();
      final after = await book();
      expect(after.sheets['سجل الزيارات'], before.sheets['سجل الزيارات'], reason: 'nothing written twice');
      expect(
        after.column('بيانات الحالات', 'اسم المريض / الحالة', headerRow: 3),
        before.column('بيانات الحالات', 'اسم المريض / الحالة', headerRow: 3),
      );
    });

    test('a second phone needs the connection code', () async {
      await connectAndLoad();
      final other = await connect(url.toString(), unspecifiedLabel: 'غير محدد');
      expect(other.failureOrNull.toString(), contains('codeRequired'));
      final withCode = await connect(url.toString(), code: (await links.read())!.key, unspecifiedLabel: 'غير محدد');
      expect(withCode.failureOrNull, isNull);
    });
  });
}
