import '../../../areas/domain/entities/area.dart';
import '../../../care_services/domain/entities/care_service.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../nurses/domain/entities/nurse.dart';
import '../../../records/domain/entities/service_record.dart';

enum ExportSheet { records, customers, nurses, services, areas }

class ExportRequest {
  const ExportRequest({this.from, this.to, this.sheets = const {...ExportSheet.values}});

  /// Optional service-date range for the Records sheet.
  final DateTime? from;
  final DateTime? to;
  final Set<ExportSheet> sheets;
}

class ExportData {
  const ExportData({
    this.records = const [],
    this.customers = const [],
    this.nurses = const [],
    this.services = const [],
    this.areas = const [],
  });

  final List<ServiceRecord> records;
  final List<Customer> customers;
  final List<Nurse> nurses;
  final List<CareService> services;
  final List<Area> areas;
}

/// Localised text used in the workbook (headers, sheet names, enum labels).
/// Supplied by the presentation layer so exports follow the app language.
class ExportLabels {
  const ExportLabels({
    required this.rtl,
    required this.sheetNames,
    required this.recordHeaders,
    required this.customerHeaders,
    required this.nurseHeaders,
    required this.serviceHeaders,
    required this.areaHeaders,
    required this.paymentLabels,
    required this.active,
    required this.inactive,
    required this.variablePrice,
    required this.total,
  });

  final bool rtl;
  final Map<ExportSheet, String> sheetNames;

  /// Record ID, Customer Name, Customer Phone, Customer Address, Customer Area,
  /// Patient (if different), Nurse, Service, Price (EGP), Payment Method,
  /// Service Date, Service Time, Notes, Created At.
  final List<String> recordHeaders;

  /// Customer ID, Name, Phone, Address, Area, Records, Last Service, Created At.
  final List<String> customerHeaders;

  /// Nurse ID, Name, Phone, Status.
  final List<String> nurseHeaders;

  /// Service ID, Name, Default Price (EGP), Status.
  final List<String> serviceHeaders;

  /// Area ID, Name, Status.
  final List<String> areaHeaders;
  final Map<PaymentMethod, String> paymentLabels;
  final String active;
  final String inactive;
  final String variablePrice;
  final String total;

  /// English labels (also used by tests and as the import round-trip format).
  static const english = ExportLabels(
    rtl: false,
    sheetNames: {
      ExportSheet.records: 'Records',
      ExportSheet.customers: 'Customers',
      ExportSheet.nurses: 'Nurses',
      ExportSheet.services: 'Services',
      ExportSheet.areas: 'Areas',
    },
    recordHeaders: [
      'Record ID',
      'Customer Name',
      'Customer Phone',
      'Customer Address',
      'Customer Area',
      'Patient (if different)',
      'Nurse',
      'Service',
      'Price (EGP)',
      'Payment Method',
      'Service Date',
      'Service Time',
      'Notes',
      'Created At',
    ],
    customerHeaders: ['Customer ID', 'Name', 'Phone', 'Address', 'Area', 'Records', 'Last Service', 'Created At'],
    nurseHeaders: ['Nurse ID', 'Name', 'Phone', 'Status'],
    serviceHeaders: ['Service ID', 'Name', 'Default Price (EGP)', 'Status'],
    areaHeaders: ['Area ID', 'Name', 'Status'],
    paymentLabels: {
      PaymentMethod.cash: 'Cash',
      PaymentMethod.electronic: 'Electronic',
      PaymentMethod.unspecified: 'Unspecified',
    },
    active: 'Active',
    inactive: 'Inactive',
    variablePrice: 'Variable',
    total: 'Total',
  );
}

/// A generated workbook ready to be saved or shared.
class ExportFile {
  const ExportFile({required this.fileName, required this.bytes, required this.recordCount});

  final String fileName;
  final List<int> bytes;
  final int recordCount;
}
