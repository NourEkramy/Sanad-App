import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/service_record.dart';
import '../../domain/usecases/record_usecases.dart';

class RecordDetailsState extends Equatable {
  const RecordDetailsState({this.record, this.loading = true, this.busy = false, this.failure, this.archived = false});

  final ServiceRecord? record;
  final bool loading;
  final bool busy;
  final Failure? failure;
  final bool archived;

  @override
  List<Object?> get props => [record, loading, busy, failure, archived];
}

class RecordDetailsCubit extends Cubit<RecordDetailsState> {
  RecordDetailsCubit({
    required this.recordId,
    required GetRecord getRecord,
    required ArchiveServiceRecord archive,
    required DiscardPendingRecord discard,
    ServiceRecord? initial,
  }) : _getRecord = getRecord,
       _archive = archive,
       _discard = discard,
       super(RecordDetailsState(record: initial, loading: initial == null));

  final String recordId;
  final GetRecord _getRecord;
  final ArchiveServiceRecord _archive;
  final DiscardPendingRecord _discard;

  Future<void> load() async {
    final result = await _getRecord(recordId);
    if (isClosed) return;
    emit(
      result.fold(
        (f) => RecordDetailsState(record: state.record, loading: false, failure: state.record == null ? f : null),
        (record) => RecordDetailsState(record: record, loading: false),
      ),
    );
  }

  void replace(ServiceRecord record) => emit(RecordDetailsState(record: record, loading: false));

  Future<Failure?> archive() async {
    emit(RecordDetailsState(record: state.record, loading: false, busy: true));
    final record = state.record;
    if (record != null && record.syncState != SyncState.synced) {
      await _discard(record.id);
      emit(RecordDetailsState(record: record, loading: false, archived: true));
      return null;
    }
    final result = await _archive(recordId);
    if (isClosed) return null;
    final failure = result.failureOrNull;
    emit(RecordDetailsState(record: state.record, loading: false, archived: failure == null));
    return failure;
  }
}
