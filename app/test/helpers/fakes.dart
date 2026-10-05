import 'dart:async';

import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/core/result/result.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/core/utils/phone_number.dart';
import 'package:sanad/core/utils/text_normalizer.dart';
import 'package:sanad/features/areas/domain/entities/area.dart';
import 'package:sanad/features/areas/domain/repositories/area_repository.dart';
import 'package:sanad/features/care_services/domain/entities/care_service.dart';
import 'package:sanad/features/care_services/domain/repositories/care_service_repository.dart';
import 'package:sanad/features/customers/domain/entities/customer.dart';
import 'package:sanad/features/customers/domain/repositories/customer_repository.dart';
import 'package:sanad/features/nurses/domain/entities/nurse.dart';
import 'package:sanad/features/nurses/domain/repositories/nurse_repository.dart';
import 'package:sanad/features/records/domain/entities/record_draft.dart';
import 'package:sanad/features/records/domain/entities/record_filter.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';
import 'package:sanad/features/records/domain/repositories/record_repository.dart';

/// In-memory repositories that mirror the database rules relevant to the
/// domain (unique phone, unique area name, active-only references, …).

final testNow = DateTime(2026, 9, 12, 19, 30);

Customer customer({
  String id = 'c1',
  String name = 'Ahmed Mohamed',
  String? phone = '01012345678',
  String areaId = 'a1',
  String areaName = 'Smouha',
  String? address = 'Street 1',
  bool archived = false,
}) => Customer(
  id: id,
  fullName: name,
  phone: phone,
  areaId: areaId,
  areaName: areaName,
  address: address,
  isArchived: archived,
  createdAt: testNow,
);

class FakeCustomerRepository implements CustomerRepository {
  final Map<String, Customer> byId = {};
  int _seq = 0;
  int searchCalls = 0;
  Failure? failNext;

  void add(Customer c) => byId[c.id] = c;

  Result<T>? _fail<T>() {
    final f = failNext;
    if (f == null) return null;
    failNext = null;
    return Result.failure(f);
  }

  @override
  Future<Result<List<Customer>>> search(String query, {int limit = 20}) async {
    searchCalls++;
    if (_fail<List<Customer>>() case final f?) return f;
    final live = byId.values.where((c) => !c.isArchived);
    if (PhoneNumber.looksLikeDigits(query)) {
      return Result.success(
        live
            .where((c) => (c.phone ?? '').startsWith(query) || (query.length >= 4 && (c.phone ?? '').contains(query)))
            .toList(),
      );
    }
    final key = TextNormalizer.key(query);
    return Result.success(live.where((c) => TextNormalizer.key(c.fullName).contains(key)).toList());
  }

  @override
  Future<Result<Customer?>> findByPhone(String normalizedPhone) async {
    if (_fail<Customer?>() case final f?) return f;
    return Result.success(byId.values.where((c) => c.phone == normalizedPhone).firstOrNull);
  }

  @override
  Future<Result<Customer>> getById(String id) async =>
      byId[id] == null ? const Result.failure(NotFoundFailure()) : Result.success(byId[id]!);

  @override
  Future<Result<List<Customer>>> list({
    int offset = 0,
    int limit = 30,
    String? areaId,
    bool needsReviewOnly = false,
  }) async => Result.success(byId.values.skip(offset).take(limit).toList());

  @override
  Future<Result<Customer>> create({
    required String fullName,
    required String phone,
    required String areaId,
    String? address,
    String? notes,
  }) async {
    if (_fail<Customer>() case final f?) return f;
    if (byId.values.any((c) => c.phone == phone)) return const Result.failure(DuplicateFailure('phone'));
    final c = Customer(
      id: 'c${++_seq}-new',
      fullName: fullName,
      phone: phone,
      areaId: areaId,
      areaName: 'Area $areaId',
      address: address,
      notes: notes,
      createdAt: testNow,
    );
    byId[c.id] = c;
    return Result.success(c);
  }

  @override
  Future<Result<Customer>> update(
    String id, {
    required String fullName,
    required String phone,
    required String areaId,
    String? address,
    String? notes,
  }) async {
    final old = byId[id]!;
    final c = Customer(
      id: id,
      fullName: fullName,
      phone: phone,
      areaId: areaId,
      areaName: old.areaName,
      address: address,
      notes: notes,
      createdAt: old.createdAt,
    );
    byId[id] = c;
    return Result.success(c);
  }

  @override
  Future<VoidResult> setArchived(String id, {required bool archived}) async => ok;
}

class FakeRecordRepository implements RecordRepository {
  final Map<String, NewServiceRecord> inserted = {};
  final Set<String> inactiveNurses = {};
  Failure? failWith;
  int addCalls = 0;

  @override
  Future<Result<ServiceRecord>> add(NewServiceRecord record) async {
    addCalls++;
    if (failWith != null) return Result.failure(failWith!);
    if (inactiveNurses.contains(record.nurseId)) return const Result.failure(BusinessRuleFailure('nurse_inactive'));
    inserted.putIfAbsent(record.id, () => record); // saving the same id twice is a no-op
    return Result.success(_toRecord(inserted[record.id]!));
  }

  static ServiceRecord _toRecord(NewServiceRecord r) => ServiceRecord(
    id: r.id,
    customerId: r.customerId,
    customerName: r.customerName,
    customerPhone: r.customerPhone,
    customerAddress: r.customerAddress,
    areaName: r.areaName,
    patientName: r.patientName,
    nurseId: r.nurseId,
    nurseName: r.nurseName,
    serviceId: r.serviceId,
    serviceName: r.serviceName,
    price: r.price,
    paymentMethod: r.paymentMethod,
    serviceDate: r.serviceDate,
    serviceTime: r.serviceTime,
    notes: r.notes,
    createdAt: r.createdAt,
  );

  @override
  Future<Result<List<ServiceRecord>>> customerHistory(String customerId) async {
    if (failWith != null) return Result.failure(failWith!);
    final list = inserted.values.where((r) => r.customerId == customerId).map(_toRecord).toList()
      ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return Result.success(list);
  }

  @override
  Future<Result<ServiceRecord>> getById(String id) async =>
      inserted[id] == null ? const Result.failure(NotFoundFailure()) : Result.success(_toRecord(inserted[id]!));

  @override
  Future<Result<List<ServiceRecord>>> list(RecordFilter filter, {int offset = 0, int limit = 30}) async =>
      Result.success(inserted.values.map(_toRecord).skip(offset).take(limit).toList());

  @override
  Future<Result<RecordTotals>> totals(RecordFilter filter) async => Result.success(
    RecordTotals(count: inserted.length, revenuePiasters: inserted.values.fold(0, (sum, r) => sum + r.price.piasters)),
  );

  @override
  Future<Result<ServiceRecord>> update(
    String id, {
    required String nurseId,
    required String serviceId,
    required Money price,
    required PaymentMethod paymentMethod,
    required DateTime serviceDate,
    required LocalTime serviceTime,
    String? patientName,
    String? notes,
  }) async => getById(id);

  @override
  Future<VoidResult> archive(String id) async => ok;
}

class MemoryDraftStore implements RecordDraftStore {
  final Map<String, RecordDraft> drafts = {};

  @override
  Future<void> clear(String customerId) async => drafts.remove(customerId);

  @override
  Future<RecordDraft?> read(String customerId) async => drafts[customerId];

  @override
  Future<void> save(String customerId, RecordDraft draft) async => drafts[customerId] = draft;
}

class FakeAreaRepository implements AreaRepository {
  FakeAreaRepository([List<Area>? areas]) : areas = areas ?? [];
  final List<Area> areas;

  @override
  Future<Result<Area>> createArea(String name) async {
    if (areas.any((a) => TextNormalizer.sameName(a.name, name))) return const Result.failure(DuplicateFailure('name'));
    final area = Area(id: 'a${areas.length + 1}', name: name);
    areas.add(area);
    return Result.success(area);
  }

  @override
  Future<Result<List<Area>>> getAreas({bool includeInactive = false}) async =>
      Result.success(areas.where((a) => includeInactive || a.isActive).toList());

  @override
  Future<Result<Area>> updateArea(Area area) async => Result.success(area);
}

class FakeNurseRepository implements NurseRepository {
  FakeNurseRepository([List<Nurse>? nurses]) : nurses = nurses ?? [];
  final List<Nurse> nurses;

  @override
  Future<Result<Nurse>> createNurse({required String name, String? phone, String? notes}) async {
    final n = Nurse(id: 'n${nurses.length + 1}', name: name, phone: phone, notes: notes);
    nurses.add(n);
    return Result.success(n);
  }

  @override
  Future<Result<List<Nurse>>> getNurses({bool includeInactive = false}) async =>
      Result.success(nurses.where((n) => includeInactive || n.isActive).toList());

  @override
  Future<Result<Nurse>> updateNurse(Nurse nurse) async => Result.success(nurse);
}

class FakeServiceRepository implements CareServiceRepository {
  FakeServiceRepository([List<CareService>? services]) : services = services ?? [];
  final List<CareService> services;

  @override
  Future<Result<CareService>> createService({required String name, Money? defaultPrice}) async {
    final s = CareService(id: 's${services.length + 1}', name: name, defaultPrice: defaultPrice);
    services.add(s);
    return Result.success(s);
  }

  @override
  Future<Result<List<CareService>>> getServices({bool includeInactive = false}) async =>
      Result.success(services.where((s) => includeInactive || s.isActive).toList());

  @override
  Future<Result<CareService>> updateService(CareService service) async => Result.success(service);
}
