import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'secure_store.dart';

/// Persists the Supabase session in the platform keystore instead of the
/// default (plain) SharedPreferences.
class SecureSessionStorage extends LocalStorage {
  SecureSessionStorage(this._store);

  static const _key = 'sanad.auth.session';
  final KeyValueStore _store;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => (await _store.read(_key)) != null;

  @override
  Future<String?> accessToken() => _store.read(_key);

  @override
  Future<void> removePersistedSession() => _store.delete(_key);

  @override
  Future<void> persistSession(String persistSessionString) => _store.write(_key, persistSessionString);
}

/// Secure storage for the PKCE code verifier used by password-reset links.
class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this._store);

  final KeyValueStore _store;

  String _k(String key) => 'sanad.pkce.${base64Url.encode(utf8.encode(key))}';

  @override
  Future<String?> getItem({required String key}) => _store.read(_k(key));

  @override
  Future<void> removeItem({required String key}) => _store.delete(_k(key));

  @override
  Future<void> setItem({required String key, required String value}) => _store.write(_k(key), value);
}
