import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/record_filter.dart';
import '../cubit/records_list_cubit.dart';
import '../widgets/record_filter_sheet.dart';
import '../widgets/record_widgets.dart';

class RecordsPage extends StatelessWidget {
  const RecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.recordsTitle),
        actions: [
          BlocBuilder<RecordsListCubit, RecordsListState>(
            buildWhen: (a, b) => a.filter.sort != b.filter.sort,
            builder: (context, state) => PopupMenuButton<RecordSort>(
              tooltip: l.recordsSort,
              icon: const Icon(Icons.sort_rounded),
              initialValue: state.filter.sort,
              onSelected: (sort) => context.read<RecordsListCubit>().applyFilter(state.filter.copyWith(sort: sort)),
              itemBuilder: (_) => [
                PopupMenuItem(value: RecordSort.newest, child: Text(l.sortNewest)),
                PopupMenuItem(value: RecordSort.oldest, child: Text(l.sortOldest)),
                PopupMenuItem(value: RecordSort.priceHigh, child: Text(l.sortPriceHigh)),
                PopupMenuItem(value: RecordSort.priceLow, child: Text(l.sortPriceLow)),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'records-fab',
        tooltip: l.actionAddRecord,
        onPressed: () => context.push(Routes.searchForRecord()),
        child: const Icon(Icons.add_rounded),
      ),
      body: BlocBuilder<RecordsListCubit, RecordsListState>(
        builder: (context, state) {
          final cubit = context.read<RecordsListCubit>();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: cubit.queryChanged,
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: l.recordsSearchHint,
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Badge(
                      isLabelVisible: state.filter.activeCount > 0,
                      label: Text('${state.filter.activeCount}'),
                      child: IconButton.filledTonal(
                        tooltip: l.recordsFilters,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(52, 52),
                          backgroundColor: state.filter.activeCount > 0 ? AppColors.primarySoft : AppColors.surface,
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.input,
                            side: BorderSide(color: AppColors.border),
                          ),
                        ),
                        icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
                        onPressed: () async {
                          final filter = await showRecordFilterSheet(context, state);
                          if (filter != null) await cubit.applyFilter(filter);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              _TotalsBar(state: state),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: cubit.load,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) cubit.loadMore();
                      return false;
                    },
                    child: _list(context, state),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _list(BuildContext context, RecordsListState state) {
    final l = context.l10n;
    final cubit = context.read<RecordsListCubit>();
    if (state.loading && state.items.isEmpty) return const LoadingView();
    if (state.failure != null && state.items.isEmpty) {
      return ListView(
        children: [ErrorView(failure: state.failure!, onRetry: cubit.load)],
      );
    }
    if (state.items.isEmpty) {
      final filtered = state.filter.activeCount > 0 || state.filter.query.isNotEmpty;
      return ListView(
        children: [
          EmptyView(
            icon: Icons.receipt_long_rounded,
            title: l.recordsEmptyTitle,
            message: filtered ? l.recordsEmptyBody : l.recordsNoneYetBody,
            action: filtered
                ? OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
                    onPressed: () => cubit.applyFilter(state.filter.cleared()),
                    child: Text(l.filterClearAll),
                  )
                : null,
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
      itemCount: state.items.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) {
        final index = i;
        if (index >= state.items.length) {
          return state.hasMore
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink();
        }
        final record = state.items[index];
        return RecordTile(
          record: record,
          showCustomer: true,
          onTap: () async {
            final changed = await context.push<bool>(Routes.record(record.id), extra: record);
            if ((changed ?? false) && context.mounted) await cubit.load();
          },
        );
      },
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({required this.state});
  final RecordsListState state;

  @override
  Widget build(BuildContext context) {
    final totals = state.totals;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: totals == null
          ? const SizedBox(height: AppSpacing.xs)
          : Container(
              key: ValueKey(totals),
              margin: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xxs, AppSpacing.md, AppSpacing.xs),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: const BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.input),
              child: Row(
                children: [
                  const Icon(Icons.summarize_outlined, size: 20, color: AppColors.primaryDark),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      context.l10n.recordsTotals(
                        totals.count,
                        context.fmt.money(Money.piasters(totals.revenuePiasters)),
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                  if (state.loading)
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
            ),
    );
  }
}
