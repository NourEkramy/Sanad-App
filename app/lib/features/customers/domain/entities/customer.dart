import 'package:equatable/equatable.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.areaId,
    required this.areaName,
    required this.createdAt,
    this.address,
    this.notes,
    this.needsReview = false,
    this.isArchived = false,
    this.recordCount = 0,
    this.lastServiceDate,
  });

  final String id;
  final String fullName;

  /// Normalised local format (`01012345678`). Null only for legacy customers
  /// imported without a valid number ([needsReview] is then true).
  final String? phone;
  final String? address;
  final String areaId;
  final String areaName;
  final String? notes;
  final bool needsReview;
  final bool isArchived;
  final DateTime createdAt;
  final int recordCount;
  final DateTime? lastServiceDate;

  @override
  List<Object?> get props => [
    id,
    fullName,
    phone,
    address,
    areaId,
    areaName,
    notes,
    needsReview,
    isArchived,
    createdAt,
    recordCount,
    lastServiceDate,
  ];
}

/// Input for creating/updating a customer (raw form values).
class CustomerDraft extends Equatable {
  const CustomerDraft({required this.fullName, required this.phone, required this.areaId, this.address, this.notes});

  final String fullName;
  final String phone;
  final String? areaId;
  final String? address;
  final String? notes;

  @override
  List<Object?> get props => [fullName, phone, areaId, address, notes];
}
