import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/secure_store.dart';

/// Chosen UI language; `null` follows the device language.
class LocaleCubit extends Cubit<Locale?> {
  LocaleCubit(this._store) : super(null);

  static const _key = 'sanad.locale';
  static const supported = [Locale('en'), Locale('ar')];
  final KeyValueStore _store;

  Future<void> load() async {
    final code = await _store.read(_key);
    if (code != null && supported.any((l) => l.languageCode == code)) emit(Locale(code));
  }

  Future<void> select(Locale? locale) async {
    emit(locale);
    if (locale == null) {
      await _store.delete(_key);
    } else {
      await _store.write(_key, locale.languageCode);
    }
  }
}
