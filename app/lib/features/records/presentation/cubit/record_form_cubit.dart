import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/local_time.dart';
import '../../../care_services/domain/entities/care_service.dart';
import '../../../care_services/domain/usecases/care_service_usecases.dart';
import '../../../customers/domain/entities/customer.dart';
import '../../../nurses/domain/entities/nurse.dart';
import '../../../nurses/domain/usecases/nurse_usecases.dart';
import '../../domain/entities/record_draft.dart';
import '../../domain/entities/service_record.dart';
import '../../domain/repositories/record_repository.dart';
import '../../domain/usecases/record_usecases.dart';

enum RecordFormStatus { loading, editing, saving, saved }

class RecordFormState extends Equatable {
  const RecordFormState({
    this.status = RecordFormStatus.loading,
    this.nurses = const [],
    this.services = const [],
    this.draft = const RecordDraft(),
    this.priceEdited = false,
    this.restoredDraft = false,
    this.failure,
    this.saved,
    this.outcome,
  });

  final RecordFormStatus status;
  final List<Nurse> nurses;
  final List<CareService> services;
  final RecordDraft draft;

  /// Once the user types a price, choosing another service no longer
  /// overwrites it.
  final bool priceEdited;
  final bool restoredDraft;
  final Failure? failure;
  final ServiceRecord? saved;
  final SaveOutcome? outcome;

  CareService? get selectedService => services.where((s) => s.id == draft.serviceId).firstOrNull;

  RecordFormState copyWith({
    RecordFormStatus? status,
    List<Nurse>? nurses,
    List<CareService>? services,
    RecordDraft? draft,
    bool? priceEdited,
    bool? restoredDraft,
    Failure? failure,
    bool clearFailure = false,
    ServiceRecord? saved,
    SaveOutcome? outcome,
  }) => RecordFormState(
    status: status ?? this.status,
    nurses: nurses ?? this.nurses,
    services: services ?? this.services,
    draft: draft ?? this.draft,
    priceEdited: priceEdited ?? this.priceEdited,
    restoredDraft: restoredDraft ?? this.restoredDraft,
    failure: clearFailure ? null : failure ?? this.failure,
    saved: saved ?? this.saved,
    outcome: outcome ?? this.outcome,
  );

  @override
  List<Object?> get props => [status, nurses, services, draft, priceEdited, restoredDraft, failure, saved, outcome];
}

/// Add (or, for admins, edit) a service record for one customer.
class RecordFormCubit extends Cubit<RecordFormState> {
  RecordFormCubit({
    required this.customer,
    required GetNurses getNurses,
    required GetCareServices getServices,
    required SaveNurse saveNurse,
    required SaveCareService saveService,
    required AddServiceRecord addRecord,
    required UpdateServiceRecord updateRecord,
    required RecordDraftStore drafts,
    this.editing,
    DateTime Function()? clock,
  }) : _getNurses = getNurses,
       _getServices = getServices,
       _saveNurse = saveNurse,
       _saveService = saveService,
       _addRecord = addRecord,
       _updateRecord = updateRecord,
       _drafts = drafts,
       _clock = clock ?? DateTime.now,
       super(const RecordFormState());

  final Customer customer;
  final ServiceRecord? editing;
  final GetNurses _getNurses;
  final GetCareServices _getServices;
  final SaveNurse _saveNurse;
  final SaveCareService _saveService;
  final AddServiceRecord _addRecord;
  final UpdateServiceRecord _updateRecord;
  final RecordDraftStore _drafts;
  final DateTime Function() _clock;
  Timer? _persist;

  bool get isEditing => editing != null;

  Future<void> init() async {
    final results = await Future.wait([_getNurses(), _getServices()]);
    if (isClosed) return;
    final failure = results[0].failureOrNull ?? results[1].failureOrNull;
    var nurses = (results[0].valueOrNull as List<Nurse>?) ?? const <Nurse>[];
    var services = (results[1].valueOrNull as List<CareService>?) ?? const <CareService>[];

    RecordDraft draft;
    var restored = false;
    final record = editing;
    if (record != null) {
      draft = RecordDraft(
        nurseId: record.nurseId,
        nurseName: record.nurseName,
        serviceId: record.serviceId,
        serviceName: record.serviceName,
        price: record.price.format().replaceAll(',', ''),
        paymentMethod: record.paymentMethod == PaymentMethod.unspecified ? null : record.paymentMethod,
        serviceDate: record.serviceDate,
        serviceTime: record.serviceTime,
        patientName: record.patientName,
        notes: record.notes,
      );
      // An inactive nurse/service stays selectable for the record that uses it.
      if (nurses.every((n) => n.id != record.nurseId)) {
        nurses = [...nurses, Nurse(id: record.nurseId, name: record.nurseName, isActive: false)];
      }
      if (services.every((s) => s.id != record.serviceId)) {
        services = [...services, CareService(id: record.serviceId, name: record.serviceName, isActive: false)];
      }
    } else {
      final saved = await _drafts.read(customer.id);
      if (saved != null) {
        draft = saved;
        restored = true;
      } else {
        final now = _clock();
        draft = RecordDraft(serviceDate: Dates.dateOnly(now), serviceTime: LocalTime.fromDateTime(now));
      }
    }
    if (isClosed) return;
    emit(
      RecordFormState(
        status: RecordFormStatus.editing,
        nurses: nurses,
        services: services,
        draft: draft,
        priceEdited: isEditing || draft.price.isNotEmpty,
        restoredDraft: restored,
        failure: failure,
      ),
    );
  }

  void _update(RecordDraft draft, {required String field, bool? priceEdited}) {
    // Only the edited field's error disappears; other errors stay visible.
    final failure = state.failure;
    final remaining = failure is ValidationFailure ? failure.without(field) : null;
    emit(state.copyWith(draft: draft, priceEdited: priceEdited, failure: remaining, clearFailure: remaining == null));
    if (isEditing) return;
    _persist?.cancel();
    _persist = Timer(const Duration(milliseconds: 400), () => _drafts.save(customer.id, state.draft));
  }

  void selectNurse(Nurse nurse) => _update(
    state.draft.copyWith(nurseId: nurse.id, nurseName: nurse.name),
    field: 'nurse',
  );

  /// Selecting a service suggests its default price unless the user already
  /// typed one. The record always stores the price actually charged.
  void selectService(CareService service) {
    final suggest = !state.priceEdited && service.defaultPrice != null;
    _update(
      state.draft.copyWith(
        serviceId: service.id,
        serviceName: service.name,
        price: suggest ? service.defaultPrice!.format().replaceAll(',', '') : null,
      ),
      field: 'service',
    );
    if (suggest) fieldCleared('price');
  }

  void priceChanged(String price) => _update(
    state.draft.copyWith(price: price),
    field: 'price',
    priceEdited: price.isNotEmpty,
  );
  void paymentChanged(PaymentMethod method) =>
      _update(state.draft.copyWith(paymentMethod: method), field: 'paymentMethod');
  void dateChanged(DateTime date) => _update(state.draft.copyWith(serviceDate: date), field: 'serviceDate');
  void timeChanged(LocalTime time) => _update(state.draft.copyWith(serviceTime: time), field: 'serviceTime');
  void patientChanged(String value) => _update(state.draft.copyWith(patientName: value), field: 'patientName');
  void notesChanged(String value) => _update(state.draft.copyWith(notes: value), field: 'notes');

  void fieldCleared(String field) {
    final failure = state.failure;
    if (failure is! ValidationFailure) return;
    final rest = failure.without(field);
    emit(rest == null ? state.copyWith(clearFailure: true) : state.copyWith(failure: rest));
  }

  Future<void> discardDraft() async {
    _persist?.cancel();
    await _drafts.clear(customer.id);
    final now = _clock();
    emit(
      state.copyWith(
        draft: RecordDraft(serviceDate: Dates.dateOnly(now), serviceTime: LocalTime.fromDateTime(now)),
        priceEdited: false,
        restoredDraft: false,
        clearFailure: true,
      ),
    );
  }

  /// Staff may add a missing nurse while recording a visit.
  Future<Nurse?> addNurse(String name) async {
    final result = await _saveNurse(name: name);
    if (isClosed) return null;
    return result.fold(
      (f) {
        emit(state.copyWith(failure: f));
        return null;
      },
      (nurse) {
        emit(state.copyWith(nurses: [...state.nurses, nurse]..sort((a, b) => a.name.compareTo(b.name))));
        selectNurse(nurse);
        return nurse;
      },
    );
  }

  Future<CareService?> addService(String name) async {
    final result = await _saveService(name: name);
    if (isClosed) return null;
    return result.fold(
      (f) {
        emit(state.copyWith(failure: f));
        return null;
      },
      (service) {
        emit(state.copyWith(services: [...state.services, service]..sort((a, b) => a.name.compareTo(b.name))));
        selectService(service);
        return service;
      },
    );
  }

  Future<void> submit() async {
    if (state.status == RecordFormStatus.saving) return;
    emit(state.copyWith(status: RecordFormStatus.saving, clearFailure: true));
    final record = editing;
    if (record != null) {
      final result = await _updateRecord(record.id, state.draft);
      if (isClosed) return;
      emit(
        result.fold(
          (f) => state.copyWith(status: RecordFormStatus.editing, failure: f),
          (saved) => state.copyWith(status: RecordFormStatus.saved, saved: saved, outcome: SaveOutcome.saved),
        ),
      );
      return;
    }
    final result = await _addRecord(customer, state.draft);
    if (isClosed) return;
    switch (result) {
      case Success(value: (final saved, final outcome)):
        _persist?.cancel();
        await _drafts.clear(customer.id);
        emit(state.copyWith(status: RecordFormStatus.saved, saved: saved, outcome: outcome));
      case Err(:final failure):
        // The draft stays (on screen and on disk): nothing typed is lost.
        emit(state.copyWith(status: RecordFormStatus.editing, failure: failure));
    }
  }

  @override
  Future<void> close() async {
    // Flush a pending draft write so leaving the screen never loses input.
    if (_persist?.isActive ?? false) {
      _persist!.cancel();
      await _drafts.save(customer.id, state.draft);
    }
    return super.close();
  }
}
