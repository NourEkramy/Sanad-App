import 'package:equatable/equatable.dart';

import 'service_record.dart';

enum RecordSort { newest, oldest, priceHigh, priceLow }

class RecordFilter extends Equatable {
  const RecordFilter({
    this.from,
    this.to,
    this.nurseId,
    this.serviceId,
    this.areaId,
    this.paymentMethod,
    this.query = '',
    this.sort = RecordSort.newest,
  });

  final DateTime? from;
  final DateTime? to;
  final String? nurseId;
  final String? serviceId;
  final String? areaId;
  final PaymentMethod? paymentMethod;

  /// Customer name or phone.
  final String query;
  final RecordSort sort;

  int get activeCount => [from ?? to, nurseId, serviceId, areaId, paymentMethod].where((v) => v != null).length;

  RecordFilter copyWith({
    DateTime? Function()? from,
    DateTime? Function()? to,
    String? Function()? nurseId,
    String? Function()? serviceId,
    String? Function()? areaId,
    PaymentMethod? Function()? paymentMethod,
    String? query,
    RecordSort? sort,
  }) =>
      RecordFilter(
        from: from != null ? from() : this.from,
        to: to != null ? to() : this.to,
        nurseId: nurseId != null ? nurseId() : this.nurseId,
        serviceId: serviceId != null ? serviceId() : this.serviceId,
        areaId: areaId != null ? areaId() : this.areaId,
        paymentMethod: paymentMethod != null ? paymentMethod() : this.paymentMethod,
        query: query ?? this.query,
        sort: sort ?? this.sort,
      );

  RecordFilter cleared() => RecordFilter(query: query, sort: sort);

  @override
  List<Object?> get props => [from, to, nurseId, serviceId, areaId, paymentMethod, query, sort];
}

/// Totals for the records currently matching a filter.
class RecordTotals extends Equatable {
  const RecordTotals({required this.count, required this.revenuePiasters});

  final int count;
  final int revenuePiasters;

  @override
  List<Object?> get props => [count, revenuePiasters];
}
