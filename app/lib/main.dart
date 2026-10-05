import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/di.dart';
import 'features/excel/presentation/export_page.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // Western digits everywhere, so dates read the same way as prices and the
  // phone numbers staff type.
  DateFormat.useNativeDigitsByDefaultFor('ar', false);
  await configureDependencies(
    exportLabels: () => exportLabelsFor(SanadApp.localizations ?? lookupAppLocalizations(const Locale('ar'))),
  );
  runApp(const SanadApp());
}
