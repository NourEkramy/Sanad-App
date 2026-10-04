import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/utils/money.dart';
import '../../../records/domain/entities/service_record.dart';
import '../../../records/domain/usecases/record_usecases.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/customer_usecases.dart';

class CustomerProfileState extends Equatable {
  const CustomerProfileState({
    this.customer,
    this.history = const [],
    this.loading = true,
    this.historyLoading = true,
    this.failure,
    this.historyFailure,
    this.busy = false,
  });

  final Customer? customer;
  final List<ServiceRecord> history;
  final bool loading;
  final bool historyLoading;
  final Failure? failure;
  final Failure? historyFailure;
  final bool busy;

  Money get totalPaid => history.fold(Money.zero, (sum, r) => sum + r.price);
  DateTime? get lastVisit => history.isEmpty ? null : history.first.serviceDate;

  CustomerProfileState copyWith({
    Customer? customer,
    List<ServiceRecord>? history,
    bool? loading,
    bool? historyLoading,
    Failure? failure,
    Failure? historyFailure,
    bool clearFailures = false,
    bool? busy,
  }) => CustomerProfileState(
    customer: customer ?? this.customer,
    history: history ?? this.history,
    loading: loading ?? this.loading,
    historyLoading: historyLoading ?? this.historyLoading,
    failure: clearFailures ? null : failure ?? this.failure,
    historyFailure: clearFailures ? null : historyFailure ?? this.historyFailure,
    busy: busy ?? this.busy,
  );

  @override
  List<Object?> get props => [customer, history, loading, historyLoading, failure, historyFailure, busy];
}

class CustomerProfileCubit extends Cubit<CustomerProfileState> {
  CustomerProfileCubit({
    required this.customerId,
    required GetCustomer getCustomer,
    required GetCustomerHistory getHistory,
    required SetCustomerArchived setArchived,
    Customer? initial,
  }) : _getCustomer = getCustomer,
       _getHistory = getHistory,
       _setArchived = setArchived,
       super(CustomerProfileState(customer: initial, loading: initial == null));

  final String customerId;
  final GetCustomer _getCustomer;
  final GetCustomerHistory _getHistory;
  final SetCustomerArchived _setArchived;

  Future<void> load() async {
    emit(state.copyWith(loading: state.customer == null, historyLoading: true, clearFailures: true));
    final results = await Future.wait([_getCustomer(customerId), _getHistory(customerId)]);
    if (isClosed) return;
    final customer = results[0].valueOrNull as Customer?;
    final history = results[1].valueOrNull as List<ServiceRecord>?;
    emit(
      state.copyWith(
        customer: customer,
        history: history,
        loading: false,
        historyLoading: false,
        failure: customer == null && state.customer == null ? results[0].failureOrNull : null,
        historyFailure: results[1].failureOrNull,
      ),
    );
  }

  Future<Failure?> setArchived(bool archived) async {
    emit(state.copyWith(busy: true));
    final result = await _setArchived(customerId, archived: archived);
    if (isClosed) return null;
    emit(state.copyWith(busy: false));
    if (result.failureOrNull case final f?) return f;
    await load();
    return null;
  }
}
