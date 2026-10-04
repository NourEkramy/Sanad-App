import 'dart:async';
import 'dart:convert';

import '../../../core/storage/secure_store.dart';
import '../domain/entities/record_draft.dart';
import '../domain/entities/service_record.dart';
import '../domain/repositories/record_repository.dart';
import 'record_mapper.dart';

/// Offline queue kept in encrypted device storage. Records stay here until
/// the server confirms them, so an app restart never loses a saved record.
class SecurePendingRecordStore implements PendingRecordStore {
  SecurePendingRecordStore(this._store);

  static const _key = 'sanad.records.pending';
  final KeyValueStore _store;
  final _count = StreamController<int>.broadcast();

  Future<Map<String, ServiceRecord>> _read() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      return {for (final j in list) j['id'] as String: RecordMapper.fromLocalJson(j)};
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, ServiceRecord> records) async {
    if (records.isEmpty) {
      await _store.delete(_key);
    } else {
      await _store.write(_key, jsonEncode([for (final r in records.values) RecordMapper.toLocalJson(r)]));
    }
    _count.add(records.length);
  }

  @override
  Future<List<ServiceRecord>> all() async {
    return (await _read()).values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> put(ServiceRecord record) async {
    final records = await _read();
    records[record.id] = record;
    await _write(records);
  }

  @override
  Future<void> remove(String id) async {
    final records = await _read();
    if (records.remove(id) != null) await _write(records);
  }

  @override
  Stream<int> watchCount() async* {
    yield (await all()).length;
    yield* _count.stream;
  }
}

/// Keeps a half-filled "Add record" form per customer so that leaving the
/// screen (or the app being killed) never loses typed data.
class SecureRecordDraftStore implements RecordDraftStore {
  SecureRecordDraftStore(this._store);

  final KeyValueStore _store;

  String _key(String customerId) => 'sanad.records.draft.$customerId';

  @override
  Future<RecordDraft?> read(String customerId) async {
    final raw = await _store.read(_key(customerId));
    if (raw == null) return null;
    try {
      return RecordDraft.fromJson((jsonDecode(raw) as Map<String, dynamic>).cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String customerId, RecordDraft draft) => _store.write(_key(customerId), jsonEncode(draft.toJson()));

  @override
  Future<void> clear(String customerId) => _store.delete(_key(customerId));
}
