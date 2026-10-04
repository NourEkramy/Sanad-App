import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_fields.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/sanad_logo.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../auth/presentation/cubit/auth_form_cubits.dart';
import '../../records/presentation/cubit/sync_cubit.dart';
import 'locale_cubit.dart';

const appVersion = '1.0.0';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthCubit>();
    final user = auth.user;
    final pending = context.select<SyncCubit, int>((c) => c.state.pending);
    return Scaffold(
      appBar: AppBar(title: Text(l.moreTitle)),
      body: ListView(
        padding: AppSpacing.page,
        children: [
          if (user != null)
            Card(
              child: ListTile(
                minTileHeight: 72,
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
                leading: InitialsAvatar(user.fullName),
                title: Text(user.fullName, style: Theme.of(context).textTheme.titleMedium),
                subtitle: Text('${user.email}\n${user.isAdmin ? l.roleAdmin : l.roleStaff}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go(Routes.profile),
              ),
            ),
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
              if (auth.can(Permission.manageUsers))
                _Item(icon: Icons.manage_accounts_outlined, label: l.usersTitle, onTap: () => context.go(Routes.users)),
            ],
          ),
          SectionHeader(l.moreData),
          _Group(
            children: [
              if (auth.can(Permission.exportData))
                _Item(icon: Icons.file_download_outlined, label: l.exportTitle, onTap: () => context.go(Routes.export)),
              if (auth.can(Permission.importData))
                _Item(icon: Icons.upload_file_outlined, label: l.importTitle, onTap: () => context.go(Routes.import)),
              _Item(
                icon: Icons.cloud_sync_outlined,
                label: l.pendingSyncMenu,
                badge: pending > 0 ? '$pending' : null,
                onTap: () => context.go(Routes.pendingSync),
              ),
            ],
          ),
          SectionHeader(l.moreAccount),
          _Group(
            children: [
              _Item(icon: Icons.settings_outlined, label: l.settingsTitle, onTap: () => context.go(Routes.settings)),
              _Item(
                icon: Icons.logout_rounded,
                label: l.signOut,
                color: AppColors.error,
                onTap: () => confirmSignOut(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> confirmSignOut(BuildContext context) async {
  final l = context.l10n;
  final pending = context.read<SyncCubit>().state.pending;
  final ok = await context.confirm(
    title: l.signOut,
    message: pending > 0 ? '${l.signOutConfirm}\n\n${l.signOutPending(pending)}' : l.signOutConfirm,
    confirmLabel: l.signOut,
    destructive: true,
  );
  if (ok && context.mounted) await context.read<AuthCubit>().signOut();
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
  const _Item({required this.icon, required this.label, required this.onTap, this.badge, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 56,
    leading: Icon(icon, color: color ?? AppColors.primary),
    title: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: color)),
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

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late final _name = TextEditingController(text: context.read<AuthCubit>().user?.fullName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final user = context.watch<AuthCubit>().user;
    if (user == null) return const Scaffold();
    return BlocConsumer<ProfileNameCubit, SubmitState>(
      listener: (context, state) async {
        if (state.status == FormStatus.success) {
          context.showSuccess(l.profileSaved);
          await context.read<AuthCubit>().refresh();
        } else if (state.failure != null && state.failure is! ValidationFailure) {
          context.showFailure(state.failure!);
        }
      },
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: Text(l.userProfileTitle)),
        body: ListView(
          padding: AppSpacing.page,
          children: [
            Center(child: InitialsAvatar(user.fullName, size: 80)),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              controller: _name,
              label: l.profileName,
              prefixIcon: Icons.person_outline_rounded,
              errorText: context.fieldError(state.failure, 'fullName'),
            ),
            const SizedBox(height: AppSpacing.sm),
            PrimaryButton(
              label: l.commonSave,
              loading: state.submitting,
              onPressed: () => context.read<ProfileNameCubit>().save(_name.text),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionCard(
              child: Column(
                children: [
                  InfoRow(icon: Icons.alternate_email_rounded, label: l.profileEmail, value: user.email),
                  InfoRow(
                    icon: Icons.shield_outlined,
                    label: l.profileRole,
                    value: user.isAdmin ? l.roleAdmin : l.roleStaff,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: () => context.push('${Routes.profile}/password'),
              icon: const Icon(Icons.password_rounded),
              label: Text(l.changePassword),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              onPressed: () => confirmSignOut(context),
              icon: const Icon(Icons.logout_rounded),
              label: Text(l.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
