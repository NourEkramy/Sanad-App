import 'dart:convert';

import '../../../core/storage/secure_store.dart';
import '../domain/entities/record_draft.dart';
import '../domain/repositories/record_repository.dart';

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
