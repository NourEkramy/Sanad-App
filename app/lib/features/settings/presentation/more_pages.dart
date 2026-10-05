import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/sanad_logo.dart';
import '../../backup/presentation/backup_cubit.dart';
import 'locale_cubit.dart';

const appVersion = '1.0.0';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final backupFailed = context.select<BackupCubit, bool>((c) => c.state.failure != null);
    return Scaffold(
      appBar: AppBar(title: Text(l.moreTitle)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          SectionHeader(l.moreManage),
          _Group(
            children: [
              _Item(icon: Icons.badge_outlined, label: l.nursesTitle, onTap: () => context.go(Routes.nurses)),
              _Item(
                icon: Icons.medical_services_outlined,
                label: l.servicesTitle,
                onTap: () => context.go(Routes.services),
              ),
              _Item(icon: Icons.place_outlined, label: l.areasTitle, onTap: () => context.go(Routes.areas)),
            ],
          ),
          SectionHeader(l.moreData),
          _Group(
            children: [
              _Item(
                icon: Icons.add_to_drive_rounded,
                label: l.backupTitle,
                badge: backupFailed ? '!' : null,
                onTap: () => context.go(Routes.backup),
              ),
              _Item(icon: Icons.file_download_outlined, label: l.exportTitle, onTap: () => context.go(Routes.export)),
              _Item(icon: Icons.upload_file_outlined, label: l.importTitle, onTap: () => context.go(Routes.import)),
            ],
          ),
          SectionHeader(l.moreApp),
          _Group(
            children: [
              _Item(icon: Icons.settings_outlined, label: l.settingsTitle, onTap: () => context.go(Routes.settings)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (final (i, child) in children.indexed) ...[if (i > 0) const Divider(indent: 64), child],
      ],
    ),
  );
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 56,
    leading: Icon(icon, color: AppColors.primary),
    title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null) Badge(label: Text(badge!), backgroundColor: AppColors.warning),
        const SizedBox(width: AppSpacing.xs),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      ],
    ),
    onTap: onTap,
  );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = context.watch<LocaleCubit>().state;
    final options = {null: l.languageSystem, const Locale('en'): 'English', const Locale('ar'): 'العربية'};
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          SectionHeader(l.settingsLanguage),
          Card(
            clipBehavior: Clip.antiAlias,
            child: RadioGroup<Locale?>(
              groupValue: locale,
              onChanged: (v) => context.read<LocaleCubit>().select(v),
              child: Column(
                children: [
                  for (final MapEntry(key: value, value: label) in options.entries)
                    RadioListTile<Locale?>(value: value, title: Text(label)),
                ],
              ),
            ),
          ),
          SectionHeader(l.settingsAbout),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SanadLogo(size: 48),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.appName, style: Theme.of(context).textTheme.titleMedium),
                            Text(l.settingsVersion(appVersion), style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l.settingsPrivacy,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
