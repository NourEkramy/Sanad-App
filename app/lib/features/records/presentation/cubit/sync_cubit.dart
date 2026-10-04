import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../domain/repositories/record_repository.dart';
import '../../domain/usecases/record_usecases.dart';

class SyncQueueState extends Equatable {
  const SyncQueueState({this.pending = 0, this.syncing = false, this.online = true, this.lastReport});

  final int pending;
  final bool syncing;
  final bool online;
  final SyncReport? lastReport;

  SyncQueueState copyWith({int? pending, bool? syncing, bool? online, SyncReport? lastReport}) => SyncQueueState(
    pending: pending ?? this.pending,
    syncing: syncing ?? this.syncing,
    online: online ?? this.online,
    lastReport: lastReport ?? this.lastReport,
  );

  @override
  List<Object?> get props => [pending, syncing, online, lastReport];
}

/// Keeps the offline queue flowing: syncs at start-up, whenever the device
/// comes back online, periodically, and on demand.
class SyncCubit extends Cubit<SyncQueueState> {
  SyncCubit(this._sync, this._pending, this._connectivity) : super(const SyncQueueState());

  final SyncPendingRecords _sync;
  final PendingRecordStore _pending;
  final ConnectivityService _connectivity;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _timer;

  Future<void> start() async {
    _subscriptions
      ..add(_pending.watchCount().listen((count) => emit(state.copyWith(pending: count))))
      ..add(
        _connectivity.onStatusChange.listen((online) {
          emit(state.copyWith(online: online));
          if (online) syncNow();
        }),
      );
    emit(state.copyWith(online: await _connectivity.isOnline));
    _timer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (state.pending > 0) syncNow();
    });
    await syncNow();
  }

  Future<SyncReport?> syncNow() async {
    if (state.syncing || isClosed) return null;
    emit(state.copyWith(syncing: true));
    final report = await _sync();
    if (isClosed) return report;
    emit(state.copyWith(syncing: false, lastReport: report, pending: (await _pending.all()).length));
    return report;
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    for (final s in _subscriptions) {
      await s.cancel();
    }
    return super.close();
  }
}
