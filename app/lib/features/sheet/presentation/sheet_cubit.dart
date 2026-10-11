import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/result/result.dart';
import '../domain/sheet_link.dart';
import '../domain/sheet_sync.dart';
import '../domain/sheet_usecases.dart';

enum SheetActivity { idle, connecting, loading, syncing }

class SheetLinkState extends Equatable {
  const SheetLinkState({
    this.loaded = false,
    this.link,
    this.activity = SheetActivity.idle,
    this.failure,
    this.pending = 0,
    this.connection,
    this.needsCode = false,
    this.reloadCount = 0,
  });

  final bool loaded;
  final SheetLink? link;
  final SheetActivity activity;

  /// Why the last attempt failed (null = it worked).
  final Failure? failure;

  /// Rows waiting to be written to the sheet.
  final int pending;

  /// A spreadsheet that was read and waits for the user's choice.
  final SheetConnection? connection;

  /// The sheet is paired with another phone: its connection code is needed.
  final bool needsCode;

  /// Incremented after the phone's data was replaced, so every screen reloads.
  final int reloadCount;

  bool get connected => link != null;
  bool get busy => activity != SheetActivity.idle;
  bool get upToDate => connected && pending == 0 && failure == null;

  SheetLinkState copyWith({
    bool? loaded,
    SheetLink? Function()? link,
    SheetActivity? activity,
    Failure? Function()? failure,
    int? pending,
    SheetConnection? Function()? connection,
    bool? needsCode,
    int? reloadCount,
  }) => SheetLinkState(
    loaded: loaded ?? this.loaded,
    link: link != null ? link() : this.link,
    activity: activity ?? this.activity,
    failure: failure != null ? failure() : this.failure,
    pending: pending ?? this.pending,
    connection: connection != null ? connection() : this.connection,
    needsCode: needsCode ?? this.needsCode,
    reloadCount: reloadCount ?? this.reloadCount,
  );

  @override
  List<Object?> get props => [loaded, link, activity, failure, pending, connection, needsCode, reloadCount];
}

/// Keeps the connected Google Sheet up to date: every change is written a few
/// seconds after it is made, when the app goes to the background, and when
/// the connection comes back after a failure.
class SheetCubit extends Cubit<SheetLinkState> {
  SheetCubit({
    required ConnectSheet connect,
    required LinkSheet linkSheet,
    required SyncSheet sync,
    required SheetStore store,
    required SheetLinkStore links,
    required ConnectivityService connectivity,
    required this.unspecifiedLabel,
    this.delay = const Duration(seconds: 4),
  }) : _connect = connect,
       _linkSheet = linkSheet,
       _sync = sync,
       _store = store,
       _links = links,
       _connectivity = connectivity,
       super(const SheetLinkState());

  final ConnectSheet _connect;
  final LinkSheet _linkSheet;
  final SyncSheet _sync;
  final SheetStore _store;
  final SheetLinkStore _links;
  final ConnectivityService _connectivity;

  /// Name used for missing areas, nurses and services when loading the sheet.
  final String Function() unspecifiedLabel;

  /// Quiet time after the last change before writing to the sheet.
  final Duration delay;

  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _timer;
  int _retries = 0;
  bool _again = false;

  Future<void> start() async {
    final link = await _links.read();
    if (isClosed) return;
    emit(state.copyWith(loaded: true, link: () => link));
    await _refreshPending();
    _subscriptions
      ..add(
        _store.changes.listen((_) async {
          await _refreshPending();
          _schedule(delay);
        }),
      )
      ..add(
        _connectivity.onStatusChange.listen((online) {
          if (online && state.failure != null) _schedule(Duration.zero);
        }),
      );
    if (state.pending > 0) _schedule(Duration.zero);
  }

  // ------------------------------------------------------------ connecting

  /// Pairs with the spreadsheet at [link] and reads it.
  Future<void> connect(String link, {String? code}) async {
    if (state.busy) return;
    emit(state.copyWith(activity: SheetActivity.connecting, failure: () => null));
    final result = await _connect(link, code: code, unspecifiedLabel: unspecifiedLabel());
    if (isClosed) return;
    switch (result) {
      case Err(failure: SheetFailure(reason: SheetFailureReason.codeRequired)):
        emit(state.copyWith(activity: SheetActivity.idle, needsCode: true, failure: () => null));
      case Err(:final failure):
        emit(state.copyWith(activity: SheetActivity.idle, failure: () => failure));
      case Success(value: final connection):
        emit(state.copyWith(activity: SheetActivity.idle, needsCode: false, connection: () => connection));
        // An empty sheet simply receives this phone's data.
        if (!connection.sheetHasData) await keepPhoneData();
    }
  }

  /// Reads the connected sheet again to load all of its data into the phone.
  Future<void> reloadFromSheet() async {
    final link = state.link;
    if (link == null || state.busy) return;
    emit(state.copyWith(activity: SheetActivity.connecting, failure: () => null));
    final result = await _connect.connect(link.url, code: link.key, unspecifiedLabel: unspecifiedLabel());
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(activity: SheetActivity.idle, failure: () => failure));
      case Success(value: final connection):
        emit(state.copyWith(activity: SheetActivity.idle, connection: () => connection));
    }
  }

  /// Loads the sheet's data into the phone ([replace]: delete the phone's
  /// data first).
  Future<void> loadFromSheet({required bool replace}) async {
    final connection = state.connection;
    if (connection == null || state.busy) return;
    _timer?.cancel();
    emit(state.copyWith(activity: SheetActivity.loading, failure: () => null));
    final result = await _linkSheet.load(connection, replace: replace, unspecifiedLabel: unspecifiedLabel());
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(activity: SheetActivity.idle, failure: () => failure));
      case Success(value: final link):
        emit(
          state.copyWith(
            activity: SheetActivity.idle,
            link: () => link,
            connection: () => null,
            reloadCount: state.reloadCount + 1,
          ),
        );
        await syncNow();
    }
  }

  /// Keeps the phone's data and writes it into the sheet.
  Future<void> keepPhoneData() async {
    final connection = state.connection;
    if (connection == null) return;
    final result = await _linkSheet.keepPhoneData(connection);
    if (isClosed) return;
    switch (result) {
      case Err(:final failure):
        emit(state.copyWith(failure: () => failure));
      case Success(value: final link):
        emit(state.copyWith(link: () => link, connection: () => null));
        await _refreshPending();
        await syncNow();
    }
  }

  void cancelConnection() => emit(state.copyWith(connection: () => null, needsCode: false, failure: () => null));

  Future<void> disconnect() async {
    _timer?.cancel();
    await _links.clear();
    if (!isClosed) emit(state.copyWith(link: () => null, failure: () => null, connection: () => null));
  }

  // ------------------------------------------------------------ syncing

  /// The app went to the background: write now rather than wait.
  void appPaused() {
    if (state.connected && state.pending > 0 && !state.busy) {
      _timer?.cancel();
      unawaited(syncNow());
    }
  }

  Future<void> syncNow() async {
    _timer?.cancel();
    if (!state.connected || isClosed) return;
    if (state.busy) {
      _again = true;
      return;
    }
    emit(state.copyWith(activity: SheetActivity.syncing));
    final result = await _sync();
    if (isClosed) return;
    final link = await _links.read();
    switch (result) {
      case Success():
        _retries = 0;
        emit(state.copyWith(activity: SheetActivity.idle, failure: () => null, link: () => link));
      case Err(:final failure):
        emit(state.copyWith(activity: SheetActivity.idle, failure: () => failure, link: () => link));
        _retryLater(failure);
    }
    await _refreshPending();
    if (_again) {
      _again = false;
      _schedule(Duration.zero);
    }
  }

  void _schedule(Duration after) {
    if (!state.connected || isClosed) return;
    _timer?.cancel();
    _timer = Timer(after, syncNow);
  }

  /// Network or server problems are retried: 30 s, 1, 2, 4 … up to 15 min.
  void _retryLater(Failure failure) {
    final transient = failure is NetworkFailure || failure is ServerFailure;
    if (!transient || state.pending == 0) return;
    final seconds = min(30 * pow(2, _retries).toInt(), 900);
    _retries++;
    _schedule(Duration(seconds: seconds));
  }

  Future<void> _refreshPending() async {
    final count = await _store.pendingCount();
    if (!isClosed) emit(state.copyWith(pending: count.valueOrNull ?? state.pending));
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
