import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import 'sheet_cubit.dart';

/// Dashboard banner: invites to connect the Google Sheet, or reports that it
/// could not be updated. Hidden while everything is fine.
class SheetBanner extends StatelessWidget {
  const SheetBanner({super.key});

  @override
  Widget build(BuildContext context) => BlocBuilder<SheetCubit, SheetLinkState>(
    builder: (context, state) {
      final l = context.l10n;
      if (!state.loaded) return const SizedBox.shrink();
      final action = TextButton(onPressed: () => context.go(Routes.sheet), child: Text(l.sheetBannerAction));
      final banner = switch (state) {
        SheetLinkState(connected: false) => InlineBanner(
          message: l.sheetBannerConnect,
          icon: Icons.table_chart_rounded,
          action: action,
        ),
        SheetLinkState(failure: _?, busy: false) => InlineBanner.warning(
          message: l.sheetBannerFailed,
          icon: Icons.sync_problem_rounded,
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

/// Icon showing whether the Google Sheet is up to date; opens its screen.
class SheetStatusButton extends StatelessWidget {
  const SheetStatusButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) => BlocBuilder<SheetCubit, SheetLinkState>(
    builder: (context, state) {
      final icon = switch (state) {
        SheetLinkState(connected: false) => Icons.table_chart_outlined,
        SheetLinkState(busy: true) => Icons.sync_rounded,
        SheetLinkState(failure: _?) => Icons.sync_problem_rounded,
        SheetLinkState(upToDate: true) => Icons.cloud_done_rounded,
        _ => Icons.schedule_rounded,
      };
      return IconButton(
        tooltip: context.l10n.sheetTitle,
        onPressed: () => context.go(Routes.sheet),
        style: IconButton.styleFrom(backgroundColor: color.withValues(alpha: 0.18)),
        icon: Icon(icon, color: state.failure != null ? AppColors.warningSoft : color),
      );
    },
  );
}
