import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/feedback.dart';
import '../features/settings/presentation/locale_cubit.dart';
import '../features/sheet/presentation/sheet_cubit.dart';
import '../l10n/app_localizations.dart';
import 'di.dart';
import 'router.dart';

class SanadApp extends StatefulWidget {
  const SanadApp({super.key});

  /// Localizations of the running app (used outside the widget tree, e.g.
  /// for the name of missing areas when loading a Google Sheet).
  static AppLocalizations? localizations;

  @override
  State<SanadApp> createState() => _SanadAppState();
}

class _SanadAppState extends State<SanadApp> with WidgetsBindingObserver {
  final _locale = LocaleCubit(sl())..load();
  final _sheet = SheetCubit(
    connect: sl(),
    linkSheet: sl(),
    sync: sl(),
    store: sl(),
    links: sl(),
    connectivity: sl(),
    unspecifiedLabel: () => SanadApp.localizations?.importUnspecifiedName ?? 'غير محدد',
  )..start();
  late GoRouter _router = buildRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _sheet.appPaused();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    _sheet.close();
    _locale.close();
    super.dispose();
  }

  /// After the data was replaced by the sheet's, every screen shows old
  /// data: start again from home.
  void _reload() {
    final old = _router;
    setState(() => _router = buildRouter());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old.dispose();
      final context = _router.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) context.showSuccess(AppLocalizations.of(context).sheetLoaded);
    });
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: _locale),
      BlocProvider.value(value: _sheet),
    ],
    child: BlocListener<SheetCubit, SheetLinkState>(
      listenWhen: (a, b) => a.reloadCount != b.reloadCount,
      listener: (_, _) => _reload(),
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
