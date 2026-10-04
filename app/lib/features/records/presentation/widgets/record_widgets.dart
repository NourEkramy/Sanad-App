import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/l10n.dart';
import '../../domain/entities/service_record.dart';

extension PaymentLabel on PaymentMethod {
  String label(BuildContext context) => switch (this) {
    PaymentMethod.cash => context.l10n.paymentCash,
    PaymentMethod.electronic => context.l10n.paymentElectronic,
    PaymentMethod.unspecified => context.l10n.paymentUnspecified,
  };

  IconData get icon => switch (this) {
    PaymentMethod.cash => Icons.payments_rounded,
    PaymentMethod.electronic => Icons.credit_card_rounded,
    PaymentMethod.unspecified => Icons.help_outline_rounded,
  };

  Color get color => switch (this) {
    PaymentMethod.cash => AppColors.cash,
    PaymentMethod.electronic => AppColors.electronic,
    PaymentMethod.unspecified => AppColors.textMuted,
  };

  Color get background => switch (this) {
    PaymentMethod.cash => AppColors.successSoft,
    PaymentMethod.electronic => AppColors.electronicSoft,
    PaymentMethod.unspecified => AppColors.surfaceMuted,
  };
}

class PaymentChip extends StatelessWidget {
  const PaymentChip(this.method, {super.key});
  final PaymentMethod method;

  @override
  Widget build(BuildContext context) =>
      StatusChip(label: method.label(context), icon: method.icon, color: method.color, background: method.background);
}

class SyncChip extends StatelessWidget {
  const SyncChip(this.state, {super.key});
  final SyncState state;

  @override
  Widget build(BuildContext context) => switch (state) {
    SyncState.synced => const SizedBox.shrink(),
    SyncState.pending => StatusChip(
      label: context.l10n.recordPendingSync,
      icon: Icons.cloud_upload_outlined,
      color: AppColors.warning,
      background: AppColors.warningSoft,
    ),
    SyncState.failed => StatusChip(
      label: context.l10n.recordSyncFailed,
      icon: Icons.error_outline_rounded,
      color: AppColors.error,
      background: AppColors.errorSoft,
    ),
  };
}

/// One service record.
/// [showCustomer] adds the customer name + phone (records list); the customer
/// profile omits them because the customer is already on screen.
class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record, required this.onTap, this.showCustomer = false});

  final ServiceRecord record;
  final VoidCallback onTap;
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = context.fmt;
    final when = [
      fmt.relativeDate(record.serviceDate),
      if (record.serviceTime != null) fmt.time(record.serviceTime!),
    ].join(' — ');
    return Card(
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showCustomer) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        record.customerName,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (record.customerPhone != null)
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          record.customerPhone!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.serviceName,
                          style: showCustomer ? theme.textTheme.titleSmall : theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.nurseLabel(record.nurseName),
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                        if (record.patientName != null)
                          Text(
                            '${context.l10n.recordPatient}: ${record.patientName}',
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    fmt.money(record.price),
                    style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primaryDark),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PaymentChip(record.paymentMethod),
                  SyncChip(record.syncState),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(when, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
