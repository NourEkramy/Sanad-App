import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  // Western digits everywhere, so dates read the same way as prices and the
  // phone numbers staff type.
  DateFormat.useNativeDigitsByDefaultFor('ar', false);
  await configureDependencies();
  runApp(const SanadApp());
}
