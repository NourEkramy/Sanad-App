import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../core/config/env.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/pages/auth_pages.dart';
import '../features/records/presentation/cubit/sync_cubit.dart';
import '../features/settings/presentation/locale_cubit.dart';
import '../l10n/app_localizations.dart';
import 'di.dart';
import 'router.dart';

class SanadApp extends StatefulWidget {
  const SanadApp({super.key});

  @override
  State<SanadApp> createState() => _SanadAppState();
}

class _SanadAppState extends State<SanadApp> {
  final _locale = LocaleCubit(sl())..load();
  AuthCubit? _auth;
  SyncCubit? _sync;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    if (!Env.isConfigured) return;
    final auth = _auth = AuthCubit(sl());
    _sync = SyncCubit(sl(), sl(), sl());
    _router = buildRouter(auth);
    var started = false;
    auth.stream.listen((status) {
      // Start syncing queued records once someone is signed in.
      if (status is Authenticated && !started) {
        started = true;
        _sync!.start();
      }
    });
  }

  @override
  void dispose() {
    _router?.dispose();
    _sync?.close();
    _auth?.close();
    _locale.close();
    super.dispose();
  }

  Widget _material({required Locale? locale, GoRouter? router, Widget? home}) {
    const delegates = [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ];
    final theme = AppTheme.light();
    String title(BuildContext context) => AppLocalizations.of(context).appName;
    if (router == null) {
      return MaterialApp(
        onGenerateTitle: title,
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: delegates,
        home: home,
      );
    }
    return MaterialApp.router(
      onGenerateTitle: title,
      debugShowCheckedModeBanner: false,
      theme: theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: delegates,
      routerConfig: router,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.isConfigured) {
      return BlocProvider.value(
        value: _locale,
        child: BlocBuilder<LocaleCubit, Locale?>(
          builder: (_, locale) => _material(locale: locale, home: const NotConfiguredPage()),
        ),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _locale),
        BlocProvider.value(value: _auth!),
        BlocProvider.value(value: _sync!),
      ],
      child: BlocBuilder<LocaleCubit, Locale?>(
        builder: (_, locale) => _material(locale: locale, router: _router),
      ),
    );
  }
}
