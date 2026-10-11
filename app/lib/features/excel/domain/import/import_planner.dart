import '../../../../core/utils/local_time.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../records/domain/entities/service_record.dart';
import '../entities/sheet_table.dart';
import 'column_mapping.dart';
import 'import_plan.dart';
import 'value_parsers.dart';

/// Turns spreadsheet rows into an [ImportPlan] — pure and deterministic, so
/// the whole migration logic is unit-tested without a database.
///
/// Rules (see docs/01-excel-analysis.md for the reasoning):
///  * A row is skipped only when it cannot be a valid record: no/invalid
///    date, no/invalid price, or neither a customer name nor a phone.
///  * Customers are identified by phone. Rows with a missing/placeholder
///    phone are grouped by name and flagged `needs_review`.
///  * When one phone was used with several names (family members), the most
///    frequent name becomes the customer and the others are kept as the
///    record's patient name — nothing is lost.
///  * Each record keeps the address/area written on its own row; the customer
///    gets the most recent ones.
///  * Missing nurse/service/area become an explicit "unspecified" entry
///    rather than a guess.
class ImportPlanner {
  const ImportPlanner({required this.unspecifiedLabel});

  /// Name used for missing nurse/service/area values (e.g. "غير محدد").
  final String unspecifiedLabel;

  ImportPlan plan(SheetTable table, ColumnMapping mapping, {ExistingData existing = const ExistingData()}) {
    final rows = <_Row>[];
    final skipped = <SkippedRow>[];

    for (var r = mapping.headerRow + 1; r < table.rows.length; r++) {
      SheetCell cell(ImportField f) => mapping[f] == null ? SheetCell.empty : table.cell(r, mapping[f]!);

      // Template rows that only carry a running number are not data.
      final hasData = [
        ImportField.serviceDate,
        ImportField.customerName,
        ImportField.phone,
        ImportField.price,
        ImportField.service,
      ].any((f) => !cell(f).isEmpty);
      if (!hasData) continue;

      final raw = <String, String>{
        for (final MapEntry(key: c, value: h) in mapping.headers.entries)
          if (table.cell(r, c).text.isNotEmpty) h: table.cell(r, c).text,
      };
      final issues = <String>[];

      final date = ValueParsers.date(cell(ImportField.serviceDate));
      final price = ValueParsers.price(cell(ImportField.price));
      final time = ValueParsers.time(cell(ImportField.serviceTime));
      final payment = ValueParsers.payment(cell(ImportField.paymentMethod));
      final name = ValueParsers.text(cell(ImportField.customerName));
      final phoneText = ValueParsers.text(cell(ImportField.phone));
      final phone = PhoneNumber.isValid(phoneText) ? PhoneNumber.normalize(phoneText) : null;

      for (final issue in [date.issue, price.issue, time.issue, payment.issue]) {
        if (issue != null) issues.add(issue);
      }
      if (name == null && phone == null) issues.add(ImportIssue.customerMissing);
      if (phone == null && name != null) issues.add(ImportIssue.phoneInvalid);

      final errors = issues.where(ImportIssue.errors.contains).toList();
      if (errors.isNotEmpty) {
        skipped.add(SkippedRow(rowNumber: r + 1, raw: raw, issues: errors));
        continue;
      }

      final nurse = ValueParsers.text(cell(ImportField.nurse));
      final service = ValueParsers.text(cell(ImportField.service));
      final area = ValueParsers.text(cell(ImportField.area));
      if (nurse == null) issues.add(ImportIssue.nurseMissing);
      if (service == null) issues.add(ImportIssue.serviceMissing);
      if (area == null) issues.add(ImportIssue.areaMissing);

      rows.add(
        _Row(
          rowNumber: r + 1,
          date: date.value!,
          time: time.value,
          price: price.value!,
          payment: payment.value!,
          name: name ?? phone!,
          phone: phone,
          address: ValueParsers.text(cell(ImportField.address)),
          area: area ?? unspecifiedLabel,
          nurse: nurse ?? unspecifiedLabel,
          service: service ?? unspecifiedLabel,
          patient: ValueParsers.text(cell(ImportField.patientName)),
          notes: ValueParsers.notes(cell(ImportField.notes)),
          legacyRef: ValueParsers.text(cell(ImportField.legacyRef)),
          sheetId: ValueParsers.sheetId(cell(ImportField.sanadId)),
          raw: raw,
          warnings: issues,
        ),
      );
    }

    final areas = _entities(rows.map((r) => r.area), existing.areaKeys);
    final nurses = _entities(rows.map((r) => r.nurse), existing.nurseKeys);
    final services = _entities(rows.map((r) => r.service), existing.serviceKeys);
    final customers = _customers(rows, existing);
    final byKey = {for (final c in customers) c.key: c};

    final records = [
      for (final row in rows)
        () {
          final customer = byKey[row.customerKey]!;
          final warnings = [...row.warnings];
          final differentName = !TextNormalizer.sameName(row.name, customer.fullName);
          if (differentName && customer.phone != null) warnings.add(ImportIssue.phoneShared);
          if (customer.rowCount > 1 &&
              (!TextNormalizer.sameName(row.address, customer.address) ||
                  TextNormalizer.key(row.area) != customer.areaKey)) {
            warnings.add(ImportIssue.customerDetailsChanged);
          }
          return PlannedRecord(
            rowNumber: row.rowNumber,
            customerKey: customer.key,
            nurseKey: TextNormalizer.key(row.nurse),
            serviceKey: TextNormalizer.key(row.service),
            price: row.price,
            paymentMethod: row.payment,
            serviceDate: row.date,
            serviceTime: row.time,
            patientName: row.patient ?? (differentName ? row.name : null),
            notes: row.notes,
            legacyRef: row.legacyRef,
            address: row.address,
            areaName: row.area,
            sheetId: row.sheetId,
            raw: row.raw,
            warnings: warnings.toSet().toList(),
          );
        }(),
    ];

    return ImportPlan(
      sheetName: table.name,
      mapping: mapping,
      areas: areas,
      nurses: nurses,
      services: services,
      customers: customers,
      records: records,
      skipped: skipped,
      committedImports: existing.committedImports,
    );
  }

  /// One entity per normalised name; the most frequent spelling wins.
  List<PlannedEntity> _entities(Iterable<String> names, Set<String> existingKeys) {
    final spellings = <String, Map<String, int>>{};
    for (final name in names) {
      final key = TextNormalizer.key(name);
      final counts = spellings.putIfAbsent(key, () => {});
      counts[name] = (counts[name] ?? 0) + 1;
    }
    final result = [
      for (final MapEntry(:key, :value) in spellings.entries)
        PlannedEntity(
          key: key,
          name: _mostFrequent(value),
          exists: existingKeys.contains(key),
          rowCount: value.values.fold(0, (a, b) => a + b),
        ),
    ]..sort((a, b) => b.rowCount.compareTo(a.rowCount));
    return result;
  }

  List<PlannedCustomer> _customers(List<_Row> rows, ExistingData existing) {
    final groups = <String, List<_Row>>{};
    for (final row in rows) {
      final key = row.phone != null ? 'p:${row.phone}' : 'n:${TextNormalizer.key(row.name)}';
      row.customerKey = key;
      groups.putIfAbsent(key, () => []).add(row);
    }
    final customers = <PlannedCustomer>[];
    for (final MapEntry(:key, value: group) in groups.entries) {
      // Chronological so "latest" means the most recent visit.
      group.sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.rowNumber.compareTo(b.rowNumber);
      });
      final nameCounts = <String, int>{};
      final latestIndex = <String, int>{};
      final spelling = <String, String>{};
      for (var i = 0; i < group.length; i++) {
        final k = TextNormalizer.key(group[i].name);
        nameCounts[k] = (nameCounts[k] ?? 0) + 1;
        latestIndex[k] = i;
        spelling[k] = group[i].name;
      }
      final bestKey = nameCounts.keys.reduce((a, b) {
        final byCount = nameCounts[a]!.compareTo(nameCounts[b]!);
        if (byCount != 0) return byCount > 0 ? a : b;
        return latestIndex[a]! >= latestIndex[b]! ? a : b;
      });
      final latestAddress = group.reversed.map((r) => r.address).whereType<String>().firstOrNull;
      final phone = group.first.phone;
      customers.add(
        PlannedCustomer(
          key: key,
          fullName: spelling[bestKey]!,
          phone: phone,
          areaKey: TextNormalizer.key(group.last.area),
          address: latestAddress,
          exists: phone != null && existing.phones.contains(phone),
          needsReview: phone == null,
          otherNames: [
            for (final k in nameCounts.keys)
              if (k != bestKey) spelling[k]!,
          ],
          rowCount: group.length,
        ),
      );
    }
    customers.sort((a, b) => b.rowCount.compareTo(a.rowCount));
    return customers;
  }

  static String _mostFrequent(Map<String, int> counts) =>
      counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
}

class _Row {
  _Row({
    required this.rowNumber,
    required this.date,
    required this.time,
    required this.price,
    required this.payment,
    required this.name,
    required this.phone,
    required this.address,
    required this.area,
    required this.nurse,
    required this.service,
    required this.patient,
    required this.notes,
    required this.legacyRef,
    required this.sheetId,
    required this.raw,
    required this.warnings,
  });

  final int rowNumber;
  final DateTime date;
  final LocalTime? time;
  final Money price;
  final PaymentMethod payment;
  final String name;
  final String? phone;
  final String? address;
  final String area;
  final String nurse;
  final String service;
  final String? patient;
  final String? notes;
  final String? legacyRef;
  final String? sheetId;
  final Map<String, String> raw;
  final List<String> warnings;
  late String customerKey;
}
