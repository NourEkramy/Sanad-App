import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../cubit/customers_list_cubit.dart';
import '../widgets/customer_widgets.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final canReview = context.watch<AuthCubit>().can(Permission.editCustomers);
    return Scaffold(
      appBar: AppBar(title: Text(l.customersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers-fab',
        onPressed: () => context.push(Routes.newCustomer()),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: Text(l.actionAddCustomer),
      ),
      body: BlocBuilder<CustomersListCubit, CustomersListState>(
        builder: (context, state) {
          final cubit = context.read<CustomersListCubit>();
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) cubit.loadMore();
                return false;
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Opens the dedicated search screen (phone keypad first).
                          Semantics(
                            button: true,
                            label: l.customersSearchHint,
                            child: InkWell(
                              borderRadius: AppRadius.input,
                              onTap: () => context.push(Routes.search),
                              child: IgnorePointer(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: l.customersSearchHint,
                                    prefixIcon: const Icon(Icons.search_rounded),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (canReview) ...[
                            const SizedBox(height: AppSpacing.sm),
                            FilterChip(
                              label: Text(l.customersNeedsReview),
                              avatar: const Icon(Icons.person_search_rounded, size: 18),
                              selected: state.needsReviewOnly,
                              onSelected: (_) => cubit.toggleNeedsReview(),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                        ],
                      ),
                    ),
                  ),
                  if (state.loading && state.items.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: LoadingView())
                  else if (state.failure != null && state.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ErrorView(failure: state.failure!, onRetry: cubit.load),
                    )
                  else if (state.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyView(
                        icon: Icons.groups_rounded,
                        title: l.customersEmptyTitle,
                        message: l.customersEmptyBody,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 96),
                      sliver: SliverList.separated(
                        itemCount: state.items.length + (state.hasMore ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          if (i >= state.items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                            );
                          }
                          final c = state.items[i];
                          return CustomerTile(
                            customer: c,
                            onTap: () => context.push(Routes.customer(c.id), extra: c),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
