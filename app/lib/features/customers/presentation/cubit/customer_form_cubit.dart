import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../../areas/domain/entities/area.dart';
import '../../../areas/domain/usecases/area_usecases.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/customer_usecases.dart';

enum CustomerFormStatus { editing, saving, saved, duplicate }

class CustomerFormState extends Equatable {
  const CustomerFormState({
    this.areas = const [],
    this.areasLoading = true,
    this.areaId,
    this.status = CustomerFormStatus.editing,
    this.failure,
    this.saved,
    this.existing,
  });

  final List<Area> areas;
  final bool areasLoading;
  final String? areaId;
  final CustomerFormStatus status;
  final Failure? failure;

  /// The created/updated customer once saved.
  final Customer? saved;

  /// The customer that already owns the phone number (duplicate).
  final Customer? existing;

  Area? get selectedArea => areas.where((a) => a.id == areaId).firstOrNull;

  CustomerFormState copyWith({
    List<Area>? areas,
    bool? areasLoading,
    String? areaId,
    CustomerFormStatus? status,
    Failure? failure,
    bool clearFailure = false,
    Customer? saved,
    Customer? existing,
  }) => CustomerFormState(
    areas: areas ?? this.areas,
    areasLoading: areasLoading ?? this.areasLoading,
    areaId: areaId ?? this.areaId,
    status: status ?? this.status,
    failure: clearFailure ? null : failure ?? this.failure,
    saved: saved ?? this.saved,
    existing: existing ?? this.existing,
  );

  @override
  List<Object?> get props => [areas, areasLoading, areaId, status, failure, saved, existing];
}

/// Add / edit customer form. Duplicate phones never create a second
/// customer: the existing one is surfaced instead.
class CustomerFormCubit extends Cubit<CustomerFormState> {
  CustomerFormCubit({
    required GetAreas getAreas,
    required CreateArea createArea,
    required CreateCustomer createCustomer,
    required UpdateCustomer updateCustomer,
    this.editing,
  }) : _getAreas = getAreas,
       _createArea = createArea,
       _createCustomer = createCustomer,
       _updateCustomer = updateCustomer,
       super(CustomerFormState(areaId: editing?.areaId));

  final GetAreas _getAreas;
  final CreateArea _createArea;
  final CreateCustomer _createCustomer;
  final UpdateCustomer _updateCustomer;
  final Customer? editing;

  Future<void> loadAreas() async {
    emit(state.copyWith(areasLoading: true));
    final result = await _getAreas();
    if (isClosed) return;
    emit(
      result.fold((f) => state.copyWith(areasLoading: false, failure: f), (areas) {
        // Keep an inactive current area visible when editing.
        final current = editing;
        final list = current != null && areas.every((a) => a.id != current.areaId)
            ? [...areas, Area(id: current.areaId, name: current.areaName, isActive: false)]
            : areas;
        return state.copyWith(areasLoading: false, areas: list, clearFailure: true);
      }),
    );
  }

  void selectArea(String id) {
    emit(state.copyWith(areaId: id));
    fieldEdited('areaId');
  }

  /// Removes the error of a field as soon as the user changes it.
  void fieldEdited(String field) {
    final failure = state.failure;
    if (failure is! ValidationFailure) return;
    final rest = failure.without(field);
    emit(rest == null ? state.copyWith(clearFailure: true) : state.copyWith(failure: rest));
  }

  /// Adds (or reuses, when the name already exists) an area and selects it.
  /// Returns the area and whether it already existed.
  Future<(Area, bool)?> addArea(String name) async {
    final before = state.areas;
    final result = await _createArea(name, known: before);
    if (isClosed) return null;
    return result.fold(
      (f) {
        emit(state.copyWith(failure: f));
        return null;
      },
      (area) {
        final existed = before.any((a) => a.id == area.id);
        final areas = existed ? before : ([...before, area]..sort((a, b) => a.name.compareTo(b.name)));
        emit(state.copyWith(areas: areas, areaId: area.id, clearFailure: true));
        return (area, existed);
      },
    );
  }

  Future<void> submit({required String fullName, required String phone, String? address, String? notes}) async {
    if (state.status == CustomerFormStatus.saving) return;
    emit(state.copyWith(status: CustomerFormStatus.saving, clearFailure: true));
    final draft = CustomerDraft(fullName: fullName, phone: phone, areaId: state.areaId, address: address, notes: notes);
    final result = editing == null ? await _createCustomer(draft) : await _updateCustomer(editing!.id, draft);
    if (isClosed) return;
    switch (result.failureOrNull) {
      case CustomerExistsFailure(:final existing):
        emit(state.copyWith(status: CustomerFormStatus.duplicate, existing: existing, failure: result.failureOrNull));
      case final Failure failure:
        emit(state.copyWith(status: CustomerFormStatus.editing, failure: failure));
      case null:
        emit(state.copyWith(status: CustomerFormStatus.saved, saved: result.valueOrNull));
    }
  }

  void dismissDuplicate() =>
      emit(CustomerFormState(areas: state.areas, areasLoading: false, areaId: state.areaId, failure: state.failure));
}
