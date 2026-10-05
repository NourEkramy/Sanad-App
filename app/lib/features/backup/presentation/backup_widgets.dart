import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/backup.dart';
import 'backup_cubit.dart';

/// Dashboard banner: invites to connect Google Drive, or reports a failed
/// backup. Hidden while everything is fine.
class BackupBanner extends StatelessWidget {
  const BackupBanner({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<BackupCubit, BackupState>(
    builder: (context, state) {
      final l = context.l10n;
      if (!state.supported || !state.loaded) return const SizedBox.shrink();
      final action = TextButton(onPressed: () => context.go(Routes.backup), child: Text(l.backupBannerAction));
      final banner = switch (state) {
        BackupState(prefs: BackupPrefs(connected: false)) => InlineBanner(
          message: l.backupBannerConnect,
          icon: Icons.add_to_drive_rounded,
          action: action,
        ),
        BackupState(failure: _?, busy: false) => InlineBanner.warning(
          message: l.backupBannerFailed,
          icon: Icons.cloud_off_rounded,
          action: action,
        ),
        _ => null,
      };
      if (banner == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: banner,
      );
    },
  );
}

/// Cloud icon showing the backup state; opens the backup screen.
class BackupStatusButton extends StatelessWidget {
  const BackupStatusButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) => BlocBuilder<BackupCubit, BackupState>(
    builder: (context, state) {
      final icon = switch (state) {
        BackupState(supported: false) || BackupState(prefs: BackupPrefs(connected: false)) => Icons.cloud_outlined,
        BackupState(busy: true) => Icons.cloud_sync_rounded,
        BackupState(failure: _?) => Icons.cloud_off_rounded,
        BackupState(upToDate: true) => Icons.cloud_done_rounded,
        _ => Icons.cloud_queue_rounded,
      };
      return IconButton(
        tooltip: context.l10n.backupTitle,
        onPressed: () => context.go(Routes.backup),
        style: IconButton.styleFrom(backgroundColor: color.withValues(alpha: 0.18)),
        icon: Icon(icon, color: state.failure != null ? AppColors.warningSoft : color),
      );
    },
  );
}
