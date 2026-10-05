import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/feedback.dart';
import '../features/backup/presentation/backup_cubit.dart';
import '../features/settings/presentation/locale_cubit.dart';
import '../l10n/app_localizations.dart';
import 'di.dart';
import 'router.dart';

class SanadApp extends StatefulWidget {
  const SanadApp({super.key});

  /// Localizations of the running app (used outside the widget tree, for the
  /// Excel copy in Google Drive).
  static AppLocalizations? localizations;

  @override
  State<SanadApp> createState() => _SanadAppState();
}

class _SanadAppState extends State<SanadApp> with WidgetsBindingObserver {
  final _locale = LocaleCubit(sl())..load();
  final _backup = BackupCubit(source: sl(), cloud: sl(), prefs: sl(), connectivity: sl())..start();
  late GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _backup.appPaused();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _backup.close();
    _locale.close();
    super.dispose();
  }

  /// After a restore every screen shows old data: start again from home.
  void _restored() {
    final old = _router;
    setState(() => _router = buildRouter());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      final context = _router.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) context.showSuccess(AppLocalizations.of(context).backupRestored);
    });
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: _locale),
      BlocProvider.value(value: _backup),
    ],
    child: BlocListener<BackupCubit, BackupState>(
      listenWhen: (a, b) => a.restoreCount != b.restoreCount,
      listener: (_, _) => _restored(),
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (_, locale) => MaterialApp.router(
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router,
          builder: (context, child) {
            SanadApp.localizations = AppLocalizations.of(context);
            return child!;
          },
        ),
      ),
    ),
  );
}
