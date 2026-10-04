import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/l10n.dart';
import '../../domain/entities/customer.dart';

/// Customer row: name and phone are always shown together so staff can
/// confirm they picked the right person.
class CustomerTile extends StatelessWidget {
  const CustomerTile({super.key, required this.customer, required this.onTap, this.highlight, this.trailing});

  final Customer customer;
  final VoidCallback onTap;

  /// Part of the phone number to emphasise (the typed search digits).
  final String? highlight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final phone = customer.phone;
    return Card(
      child: InkWell(
        borderRadius: AppRadius.card,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              InitialsAvatar(customer.fullName),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (phone != null)
                      _PhoneText(phone: phone, highlight: highlight)
                    else
                      Text(l.customerNoPhone, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.warning)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _Meta(icon: Icons.place_outlined, text: customer.areaName),
                        _Meta(icon: Icons.history_rounded, text: l.customerVisits(customer.recordCount)),
                        if (customer.needsReview)
                          StatusChip(
                            label: l.customersNeedsReview,
                            color: AppColors.warning,
                            background: AppColors.warningSoft,
                          ),
                        if (customer.isArchived)
                          StatusChip(
                            label: l.customerArchived,
                            color: AppColors.textSecondary,
                            background: AppColors.surfaceMuted,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: AppColors.textMuted),
      const SizedBox(width: 3),
      Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
    ],
  );
}

class _PhoneText extends StatelessWidget {
  const _PhoneText({required this.phone, this.highlight});
  final String phone;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
      letterSpacing: 0.6,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final h = highlight?.replaceAll(RegExp(r'\D'), '') ?? '';
    final index = h.isEmpty ? -1 : phone.indexOf(h);
    // Phone numbers always read left-to-right, also in Arabic.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: index < 0
          ? Text(phone, style: base)
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: phone.substring(0, index)),
                  TextSpan(
                    text: phone.substring(index, index + h.length),
                    style: const TextStyle(color: AppColors.primary, backgroundColor: AppColors.primarySoft),
                  ),
                  TextSpan(text: phone.substring(index + h.length)),
                ],
              ),
              style: base,
            ),
    );
  }
}

/// Compact customer summary used at the top of the record form.
class CustomerSummaryCard extends StatelessWidget {
  const CustomerSummaryCard({super.key, required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(color: AppColors.primarySofter, borderRadius: AppRadius.card),
      child: Row(
        children: [
          InitialsAvatar(customer.fullName),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.fullName, style: theme.textTheme.titleMedium),
                if (customer.phone != null)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      context.fmt.phone(customer.phone),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Text(
                  [customer.areaName, if (customer.address != null) customer.address!].join(' · '),
                  textDirection: textDirectionOf(customer.address ?? customer.areaName),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_user_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
