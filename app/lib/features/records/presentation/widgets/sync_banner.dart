import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/state_views.dart';
import '../cubit/sync_cubit.dart';

/// Offline / waiting-to-sync banner shown on the dashboard and lists.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SyncCubit, SyncQueueState>(
    builder: (context, state) {
      final l = context.l10n;
      if (state.pending > 0) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InlineBanner.warning(
            icon: Icons.cloud_upload_rounded,
            message: state.syncing ? l.syncing : l.pendingSyncBanner(state.pending),
            action: TextButton(
              onPressed: state.syncing
                  ? null
                  : () => state.online ? context.read<SyncCubit>().syncNow() : context.go(Routes.pendingSync),
              child: Text(state.online ? l.syncNow : l.pendingTitle, style: const TextStyle(color: AppColors.warning)),
            ),
          ),
        );
      }
      if (!state.online) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InlineBanner(message: l.offlineBanner, icon: Icons.cloud_off_rounded),
        );
      }
      return const SizedBox.shrink();
    },
  );
}
