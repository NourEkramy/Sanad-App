import 'package:flutter/material.dart';

import '../errors/failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'failure_messages.dart';
import 'l10n.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3)),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(message!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
        ],
      ],
    ),
  );
}

/// Friendly empty / not-found state with an optional call to action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 56 : 72,
              height: compact ? 56 : 72,
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.primary, size: compact ? 28 : 34),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppSpacing.lg), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.failure, this.onRetry, this.compact = false});

  final Failure failure;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) => EmptyView(
    compact: compact,
    icon: failure is NetworkFailure ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
    title: context.failureMessage(failure),
    action: onRetry == null
        ? null
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.l10n.commonRetry),
          ),
  );
}

/// Inline banner (info / warning / error) used at the top of screens.
class InlineBanner extends StatelessWidget {
  const InlineBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_rounded,
    this.color = AppColors.info,
    this.background = AppColors.infoSoft,
    this.action,
  });

  const InlineBanner.warning({super.key, required this.message, this.action, this.icon = Icons.warning_amber_rounded})
    : color = AppColors.warning,
      background = AppColors.warningSoft;

  const InlineBanner.error({super.key, required this.message, this.action, this.icon = Icons.error_outline_rounded})
    : color = AppColors.error,
      background = AppColors.errorSoft;

  final String message;
  final IconData icon;
  final Color color;
  final Color background;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsetsDirectional.fromSTEB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
    decoration: BoxDecoration(color: background, borderRadius: AppRadius.input),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
        ?action,
      ],
    ),
  );
}
