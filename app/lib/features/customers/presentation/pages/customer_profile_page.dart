import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../records/domain/entities/service_record.dart';
import '../../../records/presentation/widgets/record_widgets.dart';
import '../../domain/entities/customer.dart';
import '../cubit/customer_profile_cubit.dart';

class CustomerProfilePage extends StatelessWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthCubit>();
    return BlocBuilder<CustomerProfileCubit, CustomerProfileState>(
      builder: (context, state) {
        final cubit = context.read<CustomerProfileCubit>();
        final customer = state.customer;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.profileTitle),
            actions: [
              if (customer != null && auth.can(Permission.editCustomers))
                IconButton(
                  tooltip: l.commonEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final updated = await context.push<Customer>(Routes.editCustomer(customer.id), extra: customer);
                    if (updated != null) await cubit.load();
                  },
                ),
              if (customer != null && auth.can(Permission.archiveCustomers))
                PopupMenuButton<String>(
                  onSelected: (_) => _toggleArchive(context, customer),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(customer.isArchived ? l.restoreCustomer : l.archiveCustomer),
                    ),
                  ],
                ),
            ],
          ),
          floatingActionButton: customer == null || customer.isArchived
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'profile-fab',
                  onPressed: () async {
                    await context.push(Routes.addRecord(customer.id), extra: customer);
                    await cubit.load();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.profileAddRecord),
                ),
          body: switch (state) {
            CustomerProfileState(loading: true, customer: null) => const LoadingView(),
            CustomerProfileState(customer: null, :final failure?) => ErrorView(failure: failure, onRetry: cubit.load),
            _ => RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 104),
                children: [
                  _Header(customer: customer!),
                  const SizedBox(height: AppSpacing.sm),
                  _Stats(state: state),
                  if (customer.needsReview) ...[
                    const SizedBox(height: AppSpacing.sm),
                    InlineBanner.warning(message: l.profileNeedsReview),
                  ],
                  if (customer.isArchived) ...[
                    const SizedBox(height: AppSpacing.sm),
                    InlineBanner(message: l.customerExistsArchived, icon: Icons.archive_outlined),
                  ],
                  SectionHeader(l.profileHistory),
                  ..._history(context, state),
                ],
              ),
            ),
          },
        );
      },
    );
  }

  List<Widget> _history(BuildContext context, CustomerProfileState state) {
    final l = context.l10n;
    if (state.historyLoading && state.history.isEmpty) {
      return const [Padding(padding: EdgeInsets.all(AppSpacing.xl), child: LoadingView())];
    }
    if (state.historyFailure != null && state.history.isEmpty) {
      return [
        ErrorView(
          failure: state.historyFailure!,
          compact: true,
          onRetry: () => context.read<CustomerProfileCubit>().load(),
        ),
      ];
    }
    if (state.history.isEmpty) {
      return [
        EmptyView(
          compact: true,
          icon: Icons.receipt_long_rounded,
          title: l.profileNoHistoryTitle,
          message: l.profileNoHistoryBody,
        ),
      ];
    }
    // Chronological list grouped by month.
    final widgets = <Widget>[];
    String? month;
    for (final ServiceRecord r in state.history) {
      final m = context.fmt.monthYear(r.serviceDate);
      if (m != month) {
        month = m;
        widgets.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xxs, AppSpacing.sm, AppSpacing.xxs, AppSpacing.xs),
            child: Text(m, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textMuted)),
          ),
        );
      }
      widgets
        ..add(
          RecordTile(
            record: r,
            onTap: () async {
              final changed = await context.push<bool>(Routes.record(r.id), extra: r);
              if ((changed ?? false) && context.mounted) await context.read<CustomerProfileCubit>().load();
            },
          ),
        )
        ..add(const SizedBox(height: AppSpacing.sm));
    }
    return widgets;
  }

  Future<void> _toggleArchive(BuildContext context, Customer customer) async {
    final l = context.l10n;
    final cubit = context.read<CustomerProfileCubit>();
    if (!customer.isArchived) {
      final ok = await context.confirm(
        title: l.archiveCustomer,
        message: l.archiveCustomerConfirm(customer.fullName),
        confirmLabel: l.archiveCustomer,
        destructive: true,
      );
      if (!ok) return;
    }
    final failure = await cubit.setArchived(!customer.isArchived);
    if (!context.mounted) return;
    if (failure != null) {
      context.showFailure(failure);
    } else {
      context.showSuccess(customer.isArchived ? l.customerRestoredDone : l.customerArchivedDone);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InitialsAvatar(customer.fullName, size: 56),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(customer.fullName, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 2),
                      if (customer.phone != null)
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            context.fmt.phone(customer.phone),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              letterSpacing: 0.6,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        )
                      else
                        Text(l.customerNoPhone, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.warning)),
                    ],
                  ),
                ),
                if (customer.phone != null)
                  IconButton(
                    tooltip: l.copyPhone,
                    icon: const Icon(Icons.copy_rounded, color: AppColors.textMuted),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: customer.phone!));
                      if (context.mounted) context.showInfo(l.commonCopied);
                    },
                  ),
              ],
            ),
            const Divider(height: AppSpacing.xl),
            InfoRow(icon: Icons.place_outlined, label: l.fieldArea, value: customer.areaName),
            InfoRow(icon: Icons.home_outlined, label: l.fieldAddress, value: customer.address ?? l.commonNotSet),
            if (customer.notes != null) InfoRow(icon: Icons.notes_rounded, label: l.fieldNotes, value: customer.notes!),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.state});
  final CustomerProfileState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final last = state.lastVisit;
    Widget cell(String label, String value) => Expanded(
      child: Column(
        children: [
          FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleMedium)),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
        child: Row(
          children: [
            cell(l.profileVisits, state.historyLoading && state.history.isEmpty ? '—' : '${state.history.length}'),
            cell(
              l.profileTotalSpent,
              state.historyLoading && state.history.isEmpty ? '—' : context.fmt.money(state.totalPaid),
            ),
            cell(l.profileLastVisit, last == null ? '—' : context.fmt.relativeDate(last)),
          ],
        ),
      ),
    );
  }
}
