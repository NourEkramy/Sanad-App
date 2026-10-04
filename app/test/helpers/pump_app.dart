import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/theme/app_theme.dart';
import 'package:sanad/l10n/app_localizations.dart';

extension PumpApp on WidgetTester {
  /// Pumps [child] inside a MaterialApp configured like the real app.
  Future<void> pumpApp(Widget child, {Locale locale = const Locale('en')}) async {
    await binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => binding.setSurfaceSize(null));
    await pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );
    await pump();
  }
}
