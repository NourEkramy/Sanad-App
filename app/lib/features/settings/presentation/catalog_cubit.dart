import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';

class CatalogState<T> extends Equatable {
  const CatalogState({this.items = const [], this.loading = true, this.failure, this.showInactive = false});

  final List<T> items;
  final bool loading;
  final Failure? failure;
  final bool showInactive;

  @override
  List<Object?> get props => [items, loading, failure, showInactive];
}

/// Generic list state for the reference-data screens (nurses, services,
/// areas). Saving happens through the feature's own use cases; this cubit
/// only (re)loads and filters.
class CatalogCubit<T> extends Cubit<CatalogState<T>> {
  CatalogCubit(this._load) : super(CatalogState<T>());

  final Future<Result<List<T>>> Function({bool includeInactive}) _load;

  Future<void> load() async {
    emit(CatalogState<T>(items: state.items, showInactive: state.showInactive));
    final result = await _load(includeInactive: state.showInactive);
    if (isClosed) return;
    emit(
      result.fold(
        (f) => CatalogState<T>(items: state.items, loading: false, failure: f, showInactive: state.showInactive),
        (items) => CatalogState<T>(items: items, loading: false, showInactive: state.showInactive),
      ),
    );
  }

  Future<void> toggleInactive() async {
    emit(CatalogState<T>(items: state.items, showInactive: !state.showInactive));
    await load();
  }
}
