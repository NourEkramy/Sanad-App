import '../../../core/database/sanad_database.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../domain/dashboard.dart';

class LocalDashboardRepository implements DashboardRepository {
  LocalDashboardRepository(this._db);

  final SanadDatabase _db;

  @override
  Future<Result<DashboardStats>> getStats(DateTime day) => guard(() async {
    const live = 'FROM service_records WHERE deleted_at IS NULL';
    final rows = await _db.reader.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL) AS total_customers,
        (SELECT COUNT(*) $live) AS total_records,
        (SELECT COUNT(*) $live AND service_date = ?1) AS today_records,
        (SELECT COALESCE(SUM(price), 0) $live AND service_date = ?1) AS today_revenue,
        (SELECT COALESCE(SUM(price), 0) $live AND service_date = ?1 AND payment_method = 'cash') AS today_cash,
        (SELECT COALESCE(SUM(price), 0) $live AND service_date = ?1 AND payment_method = 'electronic')
          AS today_electronic,
        (SELECT COALESCE(SUM(price), 0) $live AND service_date BETWEEN ?2 AND ?1) AS month_revenue,
        (SELECT COUNT(*) FROM nurses WHERE is_active = 1) AS active_nurses,
        (SELECT COUNT(*) FROM services WHERE is_active = 1) AS active_services,
        (SELECT COUNT(*) FROM customers WHERE deleted_at IS NULL AND needs_review = 1) AS customers_needing_review
      ''',
      [Dates.toJson(day), Dates.toJson(Dates.startOfMonth(day))],
    );
    final row = rows.first;
    int i(String k) => row[k]! as int;
    Money m(String k) => Money.piasters(i(k));
    return DashboardStats(
      totalCustomers: i('total_customers'),
      totalRecords: i('total_records'),
      todayRecords: i('today_records'),
      todayRevenue: m('today_revenue'),
      todayCash: m('today_cash'),
      todayElectronic: m('today_electronic'),
      monthRevenue: m('month_revenue'),
      activeNurses: i('active_nurses'),
      activeServices: i('active_services'),
      customersNeedingReview: i('customers_needing_review'),
    );
  });
}
