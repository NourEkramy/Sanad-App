import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../domain/dashboard.dart';

class DashboardState extends Equatable {
  const DashboardState({this.loading = true, this.stats, this.failure});

  final bool loading;
  final DashboardStats? stats;
  final Failure? failure;

  @override
  List<Object?> get props => [loading, stats, failure];
}

class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(this._getStats) : super(const DashboardState());

  final GetDashboardStats _getStats;

  Future<void> load() async {
    // Keep showing previous numbers while refreshing.
    emit(DashboardState(loading: true, stats: state.stats));
    final result = await _getStats();
    if (isClosed) return;
    emit(
      result.fold(
        (f) => DashboardState(loading: false, stats: state.stats, failure: f),
        (stats) => DashboardState(loading: false, stats: stats),
      ),
    );
  }
}
