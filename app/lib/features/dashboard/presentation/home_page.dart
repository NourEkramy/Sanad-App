import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../../sheet/presentation/sheet_widgets.dart';
import '../domain/dashboard.dart';
import 'dashboard_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: () => context.read<DashboardCubit>().load(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: _Header()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
                sliver: SliverList.list(
                  children: [
                    const SheetBanner(),
                    if ((state.stats?.customersNeedingReview ?? 0) > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: InlineBanner.warning(
                          message: context.l10n.needsReviewBanner(state.stats!.customersNeedingReview),
                          icon: Icons.person_search_rounded,
                          action: IconButton(
                            tooltip: context.l10n.customersNeedsReview,
                            onPressed: () => context.go('${Routes.customers}?review=1'),
                            icon: const Icon(Icons.chevron_right_rounded, color: AppColors.warning),
                          ),
                        ),
                      ),
                    SectionHeader(context.l10n.quickActions),
                    const _QuickActions(),
                    SectionHeader(context.l10n.todayOverview),
                    if (state.failure != null && state.stats == null)
                      ErrorView(
                        failure: state.failure!,
                        compact: true,
                        onRetry: () => context.read<DashboardCubit>().load(),
                      )
                    else
                      _TodayStats(stats: state.stats),
                    SectionHeader(context.l10n.businessOverview),
                    _BusinessStats(stats: state.stats),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final greeting = now.hour < 12 ? l.greetingMorning : l.greetingEvening;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppRadius.xl)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.fmt.weekday(now)} · ${context.fmt.date(Dates.today())}',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          greeting,
                          style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SheetStatusButton(),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              // The primary workflow starts here: one tap to phone search.
              Semantics(
                button: true,
                label: l.dashboardSearchHint,
                child: Material(
                  color: Colors.white,
                  borderRadius: AppRadius.input,
                  child: InkWell(
                    borderRadius: AppRadius.input,
                    onTap: () => context.push(Routes.search),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.search_rounded, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              l.dashboardSearchHint,
                              style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                          const Icon(Icons.dialpad_rounded, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final actions = [
      (Icons.playlist_add_rounded, l.actionAddRecord, () => context.push(Routes.searchForRecord()), true),
      (Icons.person_search_rounded, l.actionSearchCustomer, () => context.push(Routes.search), false),
      (Icons.person_add_alt_1_rounded, l.actionAddCustomer, () => context.push(Routes.newCustomer()), false),
      (Icons.file_download_outlined, l.actionExport, () => context.go(Routes.export), false),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 2.3,
      children: [
        for (final (icon, label, onTap, primary) in actions)
          _ActionTile(icon: icon, label: label, onTap: onTap, primary: primary),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.primaryDark;
    return Material(
      color: primary ? AppColors.primary : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.card,
        side: primary ? BorderSide.none : const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        customBorder: const RoundedRectangleBorder(borderRadius: AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primary ? Colors.white.withValues(alpha: 0.18) : AppColors.primarySoft,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                ),
                child: Icon(icon, color: primary ? Colors.white : AppColors.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayStats extends StatelessWidget {
  const _TodayStats({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = stats;
    String money(Money m) => context.fmt.money(m);
    return _Grid(
      children: [
        StatTile(
          icon: Icons.event_available_rounded,
          label: l.statTodayServices,
          value: s == null ? '—' : '${s.todayRecords}',
        ),
        StatTile(
          icon: Icons.payments_rounded,
          label: l.statTodayRevenue,
          value: s == null ? '—' : money(s.todayRevenue),
          color: AppColors.success,
          background: AppColors.successSoft,
        ),
        StatTile(
          icon: Icons.money_rounded,
          label: l.statCash,
          value: s == null ? '—' : money(s.todayCash),
          color: AppColors.cash,
          background: AppColors.successSoft,
        ),
        StatTile(
          icon: Icons.credit_card_rounded,
          label: l.statElectronic,
          value: s == null ? '—' : money(s.todayElectronic),
          color: AppColors.electronic,
          background: AppColors.electronicSoft,
        ),
      ],
    );
  }
}

class _BusinessStats extends StatelessWidget {
  const _BusinessStats({required this.stats});
  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = stats;
    return _Grid(
      children: [
        StatTile(
          icon: Icons.groups_rounded,
          label: l.statTotalCustomers,
          value: s == null ? '—' : '${s.totalCustomers}',
        ),
        StatTile(
          icon: Icons.receipt_long_rounded,
          label: l.statTotalRecords,
          value: s == null ? '—' : '${s.totalRecords}',
        ),
        StatTile(
          icon: Icons.calendar_month_rounded,
          label: l.statMonthRevenue,
          value: s == null ? '—' : context.fmt.money(s.monthRevenue),
          color: AppColors.success,
          background: AppColors.successSoft,
        ),
        StatTile(
          icon: Icons.medical_services_rounded,
          label: '${l.statActiveNurses} · ${l.statActiveServices}',
          value: s == null ? '—' : '${s.activeNurses} · ${s.activeServices}',
          color: AppColors.info,
          background: AppColors.infoSoft,
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: AppSpacing.sm,
    crossAxisSpacing: AppSpacing.sm,
    childAspectRatio: 1.45,
    children: children,
  );
}
