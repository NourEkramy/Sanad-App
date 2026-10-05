import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/result/result.dart';
import '../domain/backup.dart';

enum BackupActivity { idle, connecting, backingUp, restoring }

class BackupState extends Equatable {
  const BackupState({
    this.supported = true,
    this.loaded = false,
    this.prefs = const BackupPrefs(),
    this.activity = BackupActivity.idle,
    this.failure,
    this.foundBackup,
    this.choosingAccount,
    this.restoreCount = 0,
  });

  final bool supported;
  final bool loaded;
  final BackupPrefs prefs;
  final BackupActivity activity;

  /// Why the last backup / connection attempt failed (null = it worked).
  final Failure? failure;

  /// A backup found in Drive right after connecting; the user decides whether
  /// to restore it or replace it with this device's data.
  final RemoteBackup? foundBackup;

  /// The account just connected while [foundBackup] waits for that choice.
  /// It is saved only once the user has chosen, so closing the app at this
  /// point can never lead to the existing backup being overwritten.
  final String? choosingAccount;

  /// Incremented after each restore so the app reloads every screen.
  final int restoreCount;

  bool get busy => activity != BackupActivity.idle;
  bool get upToDate => prefs.connected && prefs.pendingSince == null && failure == null;

  BackupState copyWith({
    bool? supported,
    bool? loaded,
    BackupPrefs? prefs,
    BackupActivity? activity,
    Failure? Function()? failure,
    RemoteBackup? Function()? foundBackup,
    String? Function()? choosingAccount,
    int? restoreCount,
  }) => BackupState(
    supported: supported ?? this.supported,
    loaded: loaded ?? this.loaded,
    prefs: prefs ?? this.prefs,
    activity: activity ?? this.activity,
    failure: failure != null ? failure() : this.failure,
    foundBackup: foundBackup != null ? foundBackup() : this.foundBackup,
    choosingAccount: choosingAccount != null ? choosingAccount() : this.choosingAccount,
    restoreCount: restoreCount ?? this.restoreCount,
  );

  @override
  List<Object?> get props => [supported, loaded, prefs, activity, failure, foundBackup, choosingAccount, restoreCount];
}

/// Keeps the Google Drive copy up to date: every change is backed up shortly
/// after it is made, when the app goes to the background, and when the
/// connection comes back after a failed attempt.
class BackupCubit extends Cubit<BackupState> {
  BackupCubit({
    required BackupSource source,
    required CloudBackupStore cloud,
    required BackupPrefsStore prefs,
    required ConnectivityService connectivity,
    DateTime Function()? clock,
    this.delay = const Duration(seconds: 20),
  }) : _source = source,
       _cloud = cloud,
       _prefsStore = prefs,
       _connectivity = connectivity,
       _clock = clock ?? DateTime.now,
       _backUp = BackUpNow(source, cloud),
       _restore = RestoreFromDrive(source, cloud),
       super(BackupState(supported: cloud.isSupported));

  final BackupSource _source;
  final CloudBackupStore _cloud;
  final BackupPrefsStore _prefsStore;
  final ConnectivityService _connectivity;
  final DateTime Function() _clock;
  final BackUpNow _backUp;
  final RestoreFromDrive _restore;

  /// Quiet time after the last change before uploading.
  final Duration delay;

  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _timer;
  bool _changedDuringUpload = false;

  Future<void> start() async {
    final prefs = await _prefsStore.read();
    if (isClosed) return;
    emit(state.copyWith(prefs: prefs, loaded: true));
    _subscriptions
      ..add(_source.changes.listen((_) => _onChange()))
      ..add(
        _connectivity.onStatusChange.listen((online) {
          if (online && state.failure is NetworkFailure) _schedule(Duration.zero);
        }),
      );
    if (prefs.connected && prefs.pendingSince != null) _schedule(delay);
  }

  Future<void> _onChange() async {
    if (state.activity == BackupActivity.backingUp) _changedDuringUpload = true;
    if (state.activity == BackupActivity.restoring) return;
    if (state.prefs.pendingSince == null) {
      await _savePrefs(
        BackupPrefs(account: state.prefs.account, lastBackupAt: state.prefs.lastBackupAt, pendingSince: _clock()),
      );
    }
    _schedule(delay);
  }

  void _schedule(Duration after) {
    if (!state.prefs.connected || state.foundBackup != null) return;
    _timer?.cancel();
    _timer = Timer(after, backUpNow);
  }

  /// The app went to the background: upload now rather than wait.
  void appPaused() {
    if (state.prefs.connected && state.prefs.pendingSince != null && !state.busy) {
      _timer?.cancel();
      unawaited(backUpNow());
    }
  }

  Future<void> backUpNow() async {
    _timer?.cancel();
    if (!state.prefs.connected || state.busy || isClosed) return;
    _changedDuringUpload = false;
    emit(state.copyWith(activity: BackupActivity.backingUp));
    final result = await _backUp();
    if (isClosed) return;
    switch (result) {
      case Success(value: final at):
        final pending = _changedDuringUpload ? _clock() : null;
        await _savePrefs(BackupPrefs(account: state.prefs.account, lastBackupAt: at, pendingSince: pending));
        emit(state.copyWith(activity: BackupActivity.idle, failure: () => null));
        if (pending != null) _schedule(delay);
      case Err(:final failure):
        emit(state.copyWith(activity: BackupActivity.idle, failure: () => failure));
    }
  }

  /// Connects a Google account (from a button press).
  Future<void> connect() async {
    if (state.busy) return;
    emit(state.copyWith(activity: BackupActivity.connecting, failure: () => null));
    final account = await _cloud.connect();
    if (isClosed) return;
    if (account case Err(:final failure)) {
      emit(state.copyWith(activity: BackupActivity.idle, failure: () => failure));
      return;
    }
    final email = account.valueOrNull!;
    // A backup made earlier (e.g. on a previous phone) must not be
    // overwritten without asking — and not at all if Drive can't be checked.
    final remote = await _cloud.latest();
    if (isClosed) return;
    switch (remote) {
      case Err(:final failure):
        emit(state.copyWith(activity: BackupActivity.idle, failure: () => failure));
      case Success(value: final found?):
        emit(state.copyWith(activity: BackupActivity.idle, foundBackup: () => found, choosingAccount: () => email));
      case Success():
        await _savePrefs(BackupPrefs(account: email, lastBackupAt: state.prefs.lastBackupAt, pendingSince: _clock()));
        emit(state.copyWith(activity: BackupActivity.idle));
        await backUpNow();
    }
  }

  /// Keep this device's data: the backup in Drive is replaced.
  Future<void> keepDeviceData() async {
    final account = state.choosingAccount ?? state.prefs.account;
    emit(state.copyWith(foundBackup: () => null, choosingAccount: () => null));
    await _savePrefs(BackupPrefs(account: account, lastBackupAt: state.prefs.lastBackupAt, pendingSince: _clock()));
    await backUpNow();
  }

  /// Replace this device's data with the backup in Drive.
  Future<VoidResult> restore() async {
    if (state.busy) return const Result.success(null);
    _timer?.cancel();
    emit(state.copyWith(activity: BackupActivity.restoring, failure: () => null));
    final remote = state.foundBackup ?? (await _cloud.latest()).valueOrNull;
    final result = await _restore();
    if (isClosed) return result;
    switch (result) {
      case Success():
        await _savePrefs(
          BackupPrefs(
            account: state.choosingAccount ?? state.prefs.account,
            lastBackupAt: remote?.modifiedAt ?? _clock(),
          ),
        );
        emit(
          state.copyWith(
            activity: BackupActivity.idle,
            foundBackup: () => null,
            choosingAccount: () => null,
            restoreCount: state.restoreCount + 1,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(activity: BackupActivity.idle, failure: () => failure));
    }
    return result;
  }

  Future<void> disconnect() async {
    _timer?.cancel();
    await _cloud.disconnect();
    await _savePrefs(BackupPrefs(lastBackupAt: state.prefs.lastBackupAt));
    if (!isClosed) emit(state.copyWith(failure: () => null, foundBackup: () => null, choosingAccount: () => null));
  }

  Future<void> _savePrefs(BackupPrefs prefs) async {
    await _prefsStore.write(prefs);
    if (!isClosed) emit(state.copyWith(prefs: prefs));
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
