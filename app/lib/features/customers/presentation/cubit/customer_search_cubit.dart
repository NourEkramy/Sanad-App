import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/customer_usecases.dart';

enum SearchStatus { idle, loading, results, notFound, failure }

class CustomerSearchState extends Equatable {
  const CustomerSearchState({this.query = '', this.status = SearchStatus.idle, this.results = const [], this.failure});

  final String query;
  final SearchStatus status;
  final List<Customer> results;
  final Failure? failure;

  @override
  List<Object?> get props => [query, status, results, failure];
}

/// Search-as-you-type with a short debounce; stale responses are dropped so
/// fast typing never shows results for an older query.
class CustomerSearchCubit extends Cubit<CustomerSearchState> {
  CustomerSearchCubit(this._search, {this.debounce = const Duration(milliseconds: 250)})
    : super(const CustomerSearchState());

  final SearchCustomers _search;
  final Duration debounce;
  Timer? _timer;
  int _generation = 0;

  void queryChanged(String query) {
    _timer?.cancel();
    final generation = ++_generation;
    if (query.trim().isEmpty) {
      emit(const CustomerSearchState());
      return;
    }
    emit(CustomerSearchState(query: query, status: SearchStatus.loading, results: state.results));
    _timer = Timer(debounce, () => _run(query, generation));
  }

  Future<void> retry() => _run(state.query, ++_generation);

  Future<void> _run(String query, int generation) async {
    final result = await _search(query);
    if (isClosed || generation != _generation) return;
    emit(
      result.fold(
        (f) => CustomerSearchState(query: query, status: SearchStatus.failure, failure: f),
        (customers) => customers.isEmpty
            ? CustomerSearchState(
                query: query,
                // Too-short queries return nothing without asking the server.
                status: _tooShort(query) ? SearchStatus.idle : SearchStatus.notFound,
              )
            : CustomerSearchState(query: query, status: SearchStatus.results, results: customers),
      ),
    );
  }

  static bool _tooShort(String q) {
    final t = q.trim();
    final digits = RegExp(r'^[\d٠-٩+\s-]+$').hasMatch(t);
    return digits ? t.replaceAll(RegExp(r'[\s-]'), '').length < 3 : t.length < 2;
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
