import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../../../core/storage/secure_store.dart';
import '../../excel/domain/import/column_mapping.dart';

/// Header of the column where Sanad writes each row's ID (same name in the
/// connector script).
const sanadIdHeader = 'معرف سند';

/// Header added to the visits sheet when it has no payment column.
const paymentHeader = 'طريقة الدفع';

/// Where things are in the connected spreadsheet. Columns are referred to by
/// their header text, so moving columns in the sheet does not matter.
class SheetLayout extends Equatable {
  const SheetLayout({required this.visits, required this.cases, required this.lists});

  final VisitsLayout visits;
  final CasesLayout cases;
  final ListsLayout lists;

  Map<String, Object?> toJson() => {'visits': visits.toJson(), 'cases': cases.toJson(), 'lists': lists.toJson()};

  static SheetLayout fromJson(Map<String, Object?> json) => SheetLayout(
    visits: VisitsLayout.fromJson(_map(json['visits'])),
    cases: CasesLayout.fromJson(_map(json['cases'])),
    lists: ListsLayout.fromJson(_map(json['lists'])),
  );

  @override
  List<Object?> get props => [visits, cases, lists];
}

/// The visits log: one row per service record.
class VisitsLayout extends Equatable {
  const VisitsLayout({
    required this.sheet,
    required this.headerRow,
    required this.headers,
    this.weekdayHeader,
    this.monthHeader,
    this.create = const [],
  });

  /// The layout Sanad creates in a spreadsheet that has no visits sheet
  /// (same columns as the original workbook).
  factory VisitsLayout.standard() => const VisitsLayout(
    sheet: 'سجل الزيارات',
    headerRow: 1,
    headers: {
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
    },
    weekdayHeader: 'اليوم',
    monthHeader: 'الشهر',
    create: [
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
      'الشهر',
      paymentHeader,
      sanadIdHeader,
    ],
  );

  final String sheet;

  /// 1-based row of the headers.
  final int headerRow;

  /// Header text of each field's column.
  final Map<ImportField, String> headers;

  /// Derived columns the original workbook fills with formulas.
  final String? weekdayHeader;
  final String? monthHeader;

  /// Headers to create the sheet with when it does not exist yet.
  final List<String> create;

  Map<String, Object?> toJson() => {
    'sheet': sheet,
    'headerRow': headerRow,
    'headers': {for (final e in headers.entries) e.key.name: e.value},
    'weekdayHeader': weekdayHeader,
    'monthHeader': monthHeader,
    'create': create,
  };

  static VisitsLayout fromJson(Map<String, Object?> json) => VisitsLayout(
    sheet: json['sheet']! as String,
    headerRow: json['headerRow']! as int,
    headers: {
      for (final e in _map(json['headers']).entries)
        ?ImportField.values.where((f) => f.name == e.key).firstOrNull: e.value! as String,
    },
    weekdayHeader: json['weekdayHeader'] as String?,
    monthHeader: json['monthHeader'] as String?,
    create: [...((json['create'] as List?) ?? const []).cast<String>()],
  );

  @override
  List<Object?> get props => [sheet, headerRow, headers, weekdayHeader, monthHeader, create];
}

/// The customers ("cases") sheet.
class CasesLayout extends Equatable {
  const CasesLayout({
    required this.sheet,
    required this.headerRow,
    required this.name,
    required this.phone,
    this.address,
    this.area,
    this.create = const [],
  });

  factory CasesLayout.standard() => const CasesLayout(
    sheet: 'بيانات الحالات',
    headerRow: 1,
    name: 'اسم المريض / الحالة',
    phone: 'رقم التليفون',
    address: 'العنوان التفصيلي',
    area: 'المنطقة',
    create: ['اسم المريض / الحالة', 'رقم التليفون', 'العنوان التفصيلي', 'المنطقة', sanadIdHeader],
  );

  final String sheet;
  final int headerRow;
  final String name;
  final String phone;
  final String? address;
  final String? area;
  final List<String> create;

  Map<String, Object?> toJson() => {
    'sheet': sheet,
    'headerRow': headerRow,
    'name': name,
    'phone': phone,
    'address': address,
    'area': area,
    'create': create,
  };

  static CasesLayout fromJson(Map<String, Object?> json) => CasesLayout(
    sheet: json['sheet']! as String,
    headerRow: json['headerRow']! as int,
    name: json['name']! as String,
    phone: json['phone']! as String,
    address: json['address'] as String?,
    area: json['area'] as String?,
    create: [...((json['create'] as List?) ?? const []).cast<String>()],
  );

  @override
  List<Object?> get props => [sheet, headerRow, name, phone, address, area, create];
}

/// The drop-down lists sheet: one column per list.
class ListsLayout extends Equatable {
  const ListsLayout({
    required this.sheet,
    required this.headerRow,
    required this.services,
    required this.price,
    required this.nurses,
    required this.areas,
    this.create = const [],
  });

  factory ListsLayout.standard() => const ListsLayout(
    sheet: 'قوائم',
    headerRow: 1,
    services: 'الخدمات',
    price: 'السعر',
    nurses: 'الممرضين',
    areas: 'المناطق',
    create: ['الخدمات', 'السعر', 'الممرضين', 'المناطق'],
  );

  final String sheet;
  final int headerRow;
  final String services;
  final String price;
  final String nurses;
  final String areas;
  final List<String> create;

  Map<String, Object?> toJson() => {
    'sheet': sheet,
    'headerRow': headerRow,
    'services': services,
    'price': price,
    'nurses': nurses,
    'areas': areas,
    'create': create,
  };

  static ListsLayout fromJson(Map<String, Object?> json) => ListsLayout(
    sheet: json['sheet']! as String,
    headerRow: json['headerRow']! as int,
    services: json['services']! as String,
    price: json['price']! as String,
    nurses: json['nurses']! as String,
    areas: json['areas']! as String,
    create: [...((json['create'] as List?) ?? const []).cast<String>()],
  );

  @override
  List<Object?> get props => [sheet, headerRow, services, price, nurses, areas, create];
}

/// A connected spreadsheet.
class SheetLink extends Equatable {
  const SheetLink({
    required this.url,
    required this.key,
    required this.title,
    required this.layout,
    required this.connectedAt,
    this.lastSyncAt,
  });

  /// The connector's Web app URL.
  final Uri url;

  /// Pairing key returned by the connector.
  final String key;

  /// Spreadsheet name.
  final String title;
  final SheetLayout layout;
  final DateTime connectedAt;
  final DateTime? lastSyncAt;

  SheetLink copyWith({SheetLayout? layout, DateTime? lastSyncAt}) => SheetLink(
    url: url,
    key: key,
    title: title,
    layout: layout ?? this.layout,
    connectedAt: connectedAt,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );

  Map<String, Object?> toJson() => {
    'url': url.toString(),
    'key': key,
    'title': title,
    'layout': layout.toJson(),
    'connectedAt': connectedAt.toIso8601String(),
    'lastSyncAt': lastSyncAt?.toIso8601String(),
  };

  static SheetLink fromJson(Map<String, Object?> json) => SheetLink(
    url: Uri.parse(json['url']! as String),
    key: json['key']! as String,
    title: json['title']! as String,
    layout: SheetLayout.fromJson(_map(json['layout'])),
    connectedAt: DateTime.parse(json['connectedAt']! as String),
    lastSyncAt: DateTime.tryParse(json['lastSyncAt'] as String? ?? ''),
  );

  @override
  List<Object?> get props => [url, key, title, layout, connectedAt, lastSyncAt];
}

/// The connected spreadsheet, remembered on the device (the link and its key
/// are kept in the platform keystore: they give access to the sheet).
class SheetLinkStore {
  const SheetLinkStore(this._store);

  final KeyValueStore _store;
  static const _key = 'sanad.sheet';

  Future<SheetLink?> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      return SheetLink.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  Future<void> write(SheetLink link) => _store.write(_key, jsonEncode(link.toJson()));

  Future<void> clear() => _store.delete(_key);
}

Map<String, Object?> _map(Object? value) => (value as Map? ?? const {}).cast<String, Object?>();
