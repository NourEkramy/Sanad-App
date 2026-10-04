import 'package:equatable/equatable.dart';

import '../../../../core/utils/local_time.dart';
import '../../../../core/utils/money.dart';
import 'service_record.dart';

/// A validated, ready-to-save service record. [id] is generated on the device
/// so that saving is idempotent (retries and offline sync never duplicate).
class NewServiceRecord extends Equatable {
  const NewServiceRecord({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.nurseId,
    required this.nurseName,
    required this.serviceId,
    required this.serviceName,
    required this.price,
    required this.paymentMethod,
    required this.serviceDate,
    required this.serviceTime,
    required this.createdAt,
    this.customerAddress,
    this.areaName,
    this.patientName,
    this.notes,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? areaName;
  final String? patientName;
  final String nurseId;
  final String nurseName;
  final String serviceId;
  final String serviceName;
  final Money price;
  final PaymentMethod paymentMethod;
  final DateTime serviceDate;
  final LocalTime serviceTime;
  final String? notes;
  final DateTime createdAt;

  ServiceRecord toRecord({SyncState syncState = SyncState.synced, String? syncError}) => ServiceRecord(
        id: id,
        customerId: customerId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        areaName: areaName,
        patientName: patientName,
        nurseId: nurseId,
        nurseName: nurseName,
        serviceId: serviceId,
        serviceName: serviceName,
        price: price,
        paymentMethod: paymentMethod,
        serviceDate: serviceDate,
        serviceTime: serviceTime,
        notes: notes,
        createdAt: createdAt,
        syncState: syncState,
        syncError: syncError,
      );

  @override
  List<Object?> get props => [
        id,
        customerId,
        customerName,
        customerPhone,
        customerAddress,
        areaName,
        patientName,
        nurseId,
        nurseName,
        serviceId,
        serviceName,
        price,
        paymentMethod,
        serviceDate,
        serviceTime,
        notes,
        createdAt,
      ];
}

/// Raw form input for a service record, before validation.
class RecordDraft extends Equatable {
  const RecordDraft({
    this.nurseId,
    this.nurseName,
    this.serviceId,
    this.serviceName,
    this.price = '',
    this.paymentMethod,
    this.serviceDate,
    this.serviceTime,
    this.patientName,
    this.notes,
  });

  final String? nurseId;
  final String? nurseName;
  final String? serviceId;
  final String? serviceName;
  final String price;
  final PaymentMethod? paymentMethod;
  final DateTime? serviceDate;
  final LocalTime? serviceTime;
  final String? patientName;
  final String? notes;

  RecordDraft copyWith({
    String? nurseId,
    String? nurseName,
    String? serviceId,
    String? serviceName,
    String? price,
    PaymentMethod? paymentMethod,
    DateTime? serviceDate,
    LocalTime? serviceTime,
    String? patientName,
    String? notes,
  }) =>
      RecordDraft(
        nurseId: nurseId ?? this.nurseId,
        nurseName: nurseName ?? this.nurseName,
        serviceId: serviceId ?? this.serviceId,
        serviceName: serviceName ?? this.serviceName,
        price: price ?? this.price,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        serviceDate: serviceDate ?? this.serviceDate,
        serviceTime: serviceTime ?? this.serviceTime,
        patientName: patientName ?? this.patientName,
        notes: notes ?? this.notes,
      );

  Map<String, Object?> toJson() => {
        'nurseId': nurseId,
        'nurseName': nurseName,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'price': price,
        'paymentMethod': paymentMethod?.name,
        'serviceDate': serviceDate?.toIso8601String(),
        'serviceTime': serviceTime?.hhmm,
        'patientName': patientName,
        'notes': notes,
      };

  static RecordDraft fromJson(Map<String, Object?> json) => RecordDraft(
        nurseId: json['nurseId'] as String?,
        nurseName: json['nurseName'] as String?,
        serviceId: json['serviceId'] as String?,
        serviceName: json['serviceName'] as String?,
        price: json['price'] as String? ?? '',
        paymentMethod: json['paymentMethod'] == null ? null : PaymentMethod.fromJson(json['paymentMethod'] as String),
        serviceDate: DateTime.tryParse(json['serviceDate'] as String? ?? ''),
        serviceTime: LocalTime.tryParse(json['serviceTime'] as String?),
        patientName: json['patientName'] as String?,
        notes: json['notes'] as String?,
      );

  @override
  List<Object?> get props =>
      [nurseId, nurseName, serviceId, serviceName, price, paymentMethod, serviceDate, serviceTime, patientName, notes];
}
