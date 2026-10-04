import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../domain/entities/customer.dart';
import '../domain/repositories/customer_repository.dart';

class SupabaseCustomerRepository implements CustomerRepository {
  SupabaseCustomerRepository(this._client);

  final SupabaseClient _client;

  static const _view = 'customer_overview';

  static Customer fromRow(Map<String, dynamic> row) => Customer(
    id: row['id'] as String,
    fullName: row['full_name'] as String,
    phone: row['phone'] as String?,
    address: row['address'] as String?,
    areaId: row['area_id'] as String,
    areaName: row['area_name'] as String? ?? '',
    notes: row['notes'] as String?,
    needsReview: row['needs_review'] as bool? ?? false,
    isArchived: row['deleted_at'] != null,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    recordCount: (row['record_count'] as num?)?.toInt() ?? 0,
    lastServiceDate: row['last_service_date'] == null ? null : DateTime.parse(row['last_service_date'] as String),
  );

  @override
  Future<Result<List<Customer>>> search(String query, {int limit = 20}) => guard(() async {
    final rows = await _client.rpc<List<dynamic>>('search_customers', params: {'query': query, 'max_results': limit});
    return rows.cast<Map<String, dynamic>>().map(fromRow).toList();
  });

  @override
  Future<Result<Customer?>> findByPhone(String normalizedPhone) => guard(() async {
    final row = await _client.from(_view).select().eq('phone', normalizedPhone).maybeSingle();
    return row == null ? null : fromRow(row);
  });

  @override
  Future<Result<Customer>> getById(String id) => guard(() async {
    final row = await _client.from(_view).select().eq('id', id).single();
    return fromRow(row);
  });

  @override
  Future<Result<List<Customer>>> list({int offset = 0, int limit = 30, String? areaId, bool needsReviewOnly = false}) =>
      guard(() async {
        var query = _client.from(_view).select().isFilter('deleted_at', null);
        if (areaId != null) query = query.eq('area_id', areaId);
        if (needsReviewOnly) query = query.eq('needs_review', true);
        final rows = await query.order('created_at', ascending: false).range(offset, offset + limit - 1);
        return rows.map(fromRow).toList();
      });

  @override
  Future<Result<Customer>> create({
    required String fullName,
    required String phone,
    required String areaId,
    String? address,
    String? notes,
  }) => guard(() async {
    final row = await _client
        .from('customers')
        .insert({'full_name': fullName, 'phone': phone, 'area_id': areaId, 'address': address, 'notes': notes})
        .select('id')
        .single();
    final created = await _client.from(_view).select().eq('id', row['id'] as String).single();
    return fromRow(created);
  });

  @override
  Future<Result<Customer>> update(
    String id, {
    required String fullName,
    required String phone,
    required String areaId,
    String? address,
    String? notes,
  }) => guard(() async {
    await _client
        .from('customers')
        .update({
          'full_name': fullName,
          'phone': phone,
          'area_id': areaId,
          'address': address,
          'notes': notes,
          // A corrected legacy customer no longer needs review.
          'needs_review': false,
        })
        .eq('id', id)
        .select('id')
        .single();
    return fromRow(await _client.from(_view).select().eq('id', id).single());
  });

  @override
  Future<VoidResult> setArchived(String id, {required bool archived}) => guard(() async {
    await _client.rpc<void>('set_customer_archived', params: {'customer_id': id, 'archived': archived});
  });
}
