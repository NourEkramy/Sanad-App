import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/customer.dart';
import '../../domain/usecases/customer_usecases.dart';

class CustomersListState extends Equatable {
  const CustomersListState({
    this.items = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.needsReviewOnly = false,
    this.failure,
  });

  final List<Customer> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool needsReviewOnly;
  final Failure? failure;

  CustomersListState copyWith({
    List<Customer>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? needsReviewOnly,
    Failure? failure,
    bool clearFailure = false,
  }) => CustomersListState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    needsReviewOnly: needsReviewOnly ?? this.needsReviewOnly,
    failure: clearFailure ? null : failure ?? this.failure,
  );

  @override
  List<Object?> get props => [items, loading, loadingMore, hasMore, needsReviewOnly, failure];
}

class CustomersListCubit extends Cubit<CustomersListState> {
  CustomersListCubit(this._list, {bool needsReviewOnly = false})
    : super(CustomersListState(needsReviewOnly: needsReviewOnly));

  static const pageSize = 30;
  final ListCustomers _list;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearFailure: true));
    final result = await _list(limit: pageSize, needsReviewOnly: state.needsReviewOnly);
    if (isClosed) return;
    emit(
      result.fold(
        (f) => state.copyWith(loading: false, failure: f),
        (items) => state.copyWith(loading: false, items: items, hasMore: items.length == pageSize),
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    emit(state.copyWith(loadingMore: true));
    final result = await _list(offset: state.items.length, limit: pageSize, needsReviewOnly: state.needsReviewOnly);
    if (isClosed) return;
    emit(
      result.fold(
        (f) => state.copyWith(loadingMore: false, failure: f),
        (more) => state.copyWith(
          loadingMore: false,
          items: [...state.items, ...more],
          hasMore: more.length == pageSize,
          clearFailure: true,
        ),
      ),
    );
  }

  Future<void> toggleNeedsReview() async {
    emit(state.copyWith(needsReviewOnly: !state.needsReviewOnly, items: const []));
    await load();
  }
}
