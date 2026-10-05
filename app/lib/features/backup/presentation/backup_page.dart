import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_fields.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/backup.dart';
import 'backup_cubit.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.backupTitle)),
      body: BlocBuilder<BackupCubit, BackupState>(
        builder: (context, state) {
          if (!state.supported) {
            return ListView(
              padding: AppSpacing.page,
              children: [
                InlineBanner(message: l.backupUnsupported),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () => context.go(Routes.export),
                  icon: const Icon(Icons.file_download_outlined),
                  label: Text(l.exportTitle),
                ),
              ],
            );
          }
          if (!state.loaded) return const LoadingView();
          return ListView(
            padding: AppSpacing.page,
            children: [
              if (state.foundBackup case final found?) ...[
                _FoundBackup(found.modifiedAt),
                const SizedBox(height: AppSpacing.md),
              ],
              if (state.failure case final failure?) ...[
                InlineBanner.error(message: context.failureMessage(failure)),
                const SizedBox(height: AppSpacing.md),
              ],
              if (state.prefs.connected) _Connected(state) else if (state.foundBackup == null) _NotConnected(state),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l.backupWhere,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected(this.state);
  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.add_to_drive_rounded, size: 48, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(l.backupIntro, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l.backupConnect,
            icon: Icons.login_rounded,
            loading: state.activity == BackupActivity.connecting,
            onPressed: () => context.read<BackupCubit>().connect(),
          ),
        ],
      ),
    );
  }
}

class _Connected extends StatelessWidget {
  const _Connected(this.state);
  final BackupState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<BackupCubit>();
    final last = state.prefs.lastBackupAt;
    final (icon, color, status) = switch (state) {
      BackupState(activity: BackupActivity.backingUp) => (
        Icons.cloud_upload_rounded,
        AppColors.primary,
        l.backupInProgress,
      ),
      BackupState(activity: BackupActivity.restoring) => (
        Icons.cloud_download_rounded,
        AppColors.primary,
        l.backupRestoring,
      ),
      BackupState(failure: _?) => (Icons.cloud_off_rounded, AppColors.error, l.backupNotUpToDate),
      BackupState(prefs: BackupPrefs(pendingSince: _?)) => (
        Icons.cloud_queue_rounded,
        AppColors.warning,
        l.backupPendingChanges,
      ),
      _ => (Icons.cloud_done_rounded, AppColors.success, l.backupUpToDate),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(status, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              InfoRow(icon: Icons.account_circle_outlined, label: l.backupAccount, value: state.prefs.account ?? ''),
              InfoRow(
                icon: Icons.history_rounded,
                label: l.backupLast,
                value: last == null ? l.backupNever : context.fmt.dateTime(last),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: l.backupNow,
          icon: Icons.cloud_upload_outlined,
          loading: state.activity == BackupActivity.backingUp,
          onPressed: state.busy ? null : cubit.backUpNow,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: state.busy ? null : () => _confirmRestore(context),
          icon: const Icon(Icons.restore_rounded),
          label: Text(l.backupRestore),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: state.busy ? null : () => _confirmDisconnect(context),
          icon: const Icon(Icons.link_off_rounded),
          label: Text(l.backupDisconnect),
        ),
      ],
    );
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final l = context.l10n;
    final ok = await context.confirm(
      title: l.backupDisconnect,
      message: l.backupDisconnectConfirm,
      confirmLabel: l.backupDisconnect,
      destructive: true,
    );
    if (ok && context.mounted) await context.read<BackupCubit>().disconnect();
  }
}

class _FoundBackup extends StatelessWidget {
  const _FoundBackup(this.date);
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SectionCard(
      title: l.backupFoundTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.backupFoundBody(context.fmt.dateTime(date))),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: l.backupRestore, icon: Icons.restore_rounded, onPressed: () => _confirmRestore(context)),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: () => _confirmKeep(context), child: Text(l.backupKeepDevice)),
        ],
      ),
    );
  }

  Future<void> _confirmKeep(BuildContext context) async {
    final l = context.l10n;
    final ok = await context.confirm(
      title: l.backupKeepDevice,
      message: l.backupKeepDeviceConfirm,
      confirmLabel: l.backupNow,
      destructive: true,
    );
    if (ok && context.mounted) await context.read<BackupCubit>().keepDeviceData();
  }
}

/// After a restore the app reloads every screen and confirms it (see app.dart).
Future<void> _confirmRestore(BuildContext context) async {
  final l = context.l10n;
  final ok = await context.confirm(
    title: l.backupRestoreConfirmTitle,
    message: l.backupRestoreConfirm,
    confirmLabel: l.backupRestore,
    destructive: true,
  );
  if (ok && context.mounted) await context.read<BackupCubit>().restore();
}
