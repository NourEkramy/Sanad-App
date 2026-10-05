import 'package:equatable/equatable.dart';

import '../../../core/result/result.dart';
import '../../../core/utils/money.dart';

class DashboardStats extends Equatable {
  const DashboardStats({
    required this.totalCustomers,
    required this.totalRecords,
    required this.todayRecords,
    required this.todayRevenue,
    required this.todayCash,
    required this.todayElectronic,
    required this.monthRevenue,
    required this.activeNurses,
    required this.activeServices,
    required this.customersNeedingReview,
  });

  final int totalCustomers;
  final int totalRecords;
  final int todayRecords;
  final Money todayRevenue;
  final Money todayCash;
  final Money todayElectronic;
  final Money monthRevenue;
  final int activeNurses;
  final int activeServices;
  final int customersNeedingReview;

  @override
  List<Object?> get props => [
    totalCustomers,
    totalRecords,
    todayRecords,
    todayRevenue,
    todayCash,
    todayElectronic,
    monthRevenue,
    activeNurses,
    activeServices,
    customersNeedingReview,
  ];
}

abstract interface class DashboardRepository {
  Future<Result<DashboardStats>> getStats(DateTime day);
}

class GetDashboardStats {
  const GetDashboardStats(this._repository);
  final DashboardRepository _repository;

  Future<Result<DashboardStats>> call([DateTime? day]) => _repository.getStats(day ?? DateTime.now());
}
