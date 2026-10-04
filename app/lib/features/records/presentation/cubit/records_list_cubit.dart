import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../../areas/domain/entities/area.dart';
import '../../../areas/domain/usecases/area_usecases.dart';
import '../../../care_services/domain/entities/care_service.dart';
import '../../../care_services/domain/usecases/care_service_usecases.dart';
import '../../../nurses/domain/entities/nurse.dart';
import '../../../nurses/domain/usecases/nurse_usecases.dart';
import '../../domain/entities/record_filter.dart';
import '../../domain/entities/service_record.dart';
import '../../domain/usecases/record_usecases.dart';

class RecordsListState extends Equatable {
  const RecordsListState({
    this.filter = const RecordFilter(),
    this.items = const [],
    this.totals,
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.failure,
    this.nurses = const [],
    this.services = const [],
    this.areas = const [],
  });

  final RecordFilter filter;
  final List<ServiceRecord> items;
  final RecordTotals? totals;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final Failure? failure;

  /// Reference lists for the filter sheet (including inactive entries, since
  /// old records may use them).
  final List<Nurse> nurses;
  final List<CareService> services;
  final List<Area> areas;

  RecordsListState copyWith({
    RecordFilter? filter,
    List<ServiceRecord>? items,
    RecordTotals? totals,
    bool clearTotals = false,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    Failure? failure,
    bool clearFailure = false,
    List<Nurse>? nurses,
    List<CareService>? services,
    List<Area>? areas,
  }) => RecordsListState(
    filter: filter ?? this.filter,
    items: items ?? this.items,
    totals: clearTotals ? null : totals ?? this.totals,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    hasMore: hasMore ?? this.hasMore,
    failure: clearFailure ? null : failure ?? this.failure,
    nurses: nurses ?? this.nurses,
    services: services ?? this.services,
    areas: areas ?? this.areas,
  );

  @override
  List<Object?> get props => [filter, items, totals, loading, loadingMore, hasMore, failure, nurses, services, areas];
}

class RecordsListCubit extends Cubit<RecordsListState> {
  RecordsListCubit({
    required ListRecords listRecords,
    required GetRecordTotals getTotals,
    required GetNurses getNurses,
    required GetCareServices getServices,
    required GetAreas getAreas,
  }) : _list = listRecords,
       _totals = getTotals,
       _getNurses = getNurses,
       _getServices = getServices,
       _getAreas = getAreas,
       super(const RecordsListState());

  static const pageSize = 30;
  final ListRecords _list;
  final GetRecordTotals _totals;
  final GetNurses _getNurses;
  final GetCareServices _getServices;
  final GetAreas _getAreas;
  Timer? _debounce;
  int _generation = 0;

  Future<void> init() async {
    unawaited(_loadReferences());
    await load();
  }

  Future<void> _loadReferences() async {
    final results = await Future.wait([
      _getNurses(includeInactive: true),
      _getServices(includeInactive: true),
      _getAreas(includeInactive: true),
    ]);
    if (isClosed) return;
    emit(
      state.copyWith(
        nurses: results[0].valueOrNull as List<Nurse>?,
        services: results[1].valueOrNull as List<CareService>?,
        areas: results[2].valueOrNull as List<Area>?,
      ),
    );
  }

  Future<void> load() async {
    final generation = ++_generation;
    emit(state.copyWith(loading: true, clearFailure: true));
    final results = await Future.wait([_list(state.filter, limit: pageSize), _totals(state.filter)]);
    if (isClosed || generation != _generation) return;
    final items = results[0].valueOrNull as List<ServiceRecord>?;
    emit(
      state.copyWith(
        loading: false,
        items: items ?? const [],
        hasMore: (items?.length ?? 0) == pageSize,
        totals: results[1].valueOrNull as RecordTotals?,
        clearTotals: results[1].valueOrNull == null,
        failure: results[0].failureOrNull,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    final result = await _list(state.filter, offset: state.items.length, limit: pageSize);
    if (isClosed || generation != _generation) return;
    emit(
      result.fold(
        (f) => state.copyWith(loadingMore: false, failure: f),
        (more) =>
            state.copyWith(loadingMore: false, items: [...state.items, ...more], hasMore: more.length == pageSize),
      ),
    );
  }

  void queryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => applyFilter(state.filter.copyWith(query: query)));
  }

  Future<void> applyFilter(RecordFilter filter) async {
    if (filter == state.filter) return;
    emit(state.copyWith(filter: filter));
    await load();
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
