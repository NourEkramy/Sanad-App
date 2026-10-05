import 'package:equatable/equatable.dart';

import '../../../../core/utils/local_time.dart';
import '../../../../core/utils/money.dart';

enum PaymentMethod {
  cash,
  electronic,

  /// Legacy records imported from Excel, which never recorded payment method.
  unspecified;

  static PaymentMethod fromJson(String? value) => switch (value) {
    'cash' => PaymentMethod.cash,
    'electronic' => PaymentMethod.electronic,
    _ => PaymentMethod.unspecified,
  };

  String toJson() => name;

  /// Methods that can be chosen for a new record.
  static const selectable = [PaymentMethod.cash, PaymentMethod.electronic];
}

class ServiceRecord extends Equatable {
  const ServiceRecord({
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
    required this.createdAt,
    this.serviceTime,
    this.customerAddress,
    this.areaName,
    this.patientName,
    this.notes,
    this.legacyRef,
    this.isImported = false,
    this.isArchived = false,
  });

  final String id;
  final String customerId;
  final String customerName;
  final String? customerPhone;

  /// Address and area as they were when the service was provided.
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

  /// Null only for legacy records whose time could not be read.
  final LocalTime? serviceTime;
  final String? notes;
  final String? legacyRef;
  final bool isImported;
  final bool isArchived;
  final DateTime createdAt;

  DateTime get sortKey =>
      DateTime(serviceDate.year, serviceDate.month, serviceDate.day, serviceTime?.hour ?? 0, serviceTime?.minute ?? 0);

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
    legacyRef,
    isImported,
    isArchived,
    createdAt,
  ];
}
