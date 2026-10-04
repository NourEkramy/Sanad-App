import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/customer.dart';
import '../cubit/customer_search_cubit.dart';
import '../widgets/customer_widgets.dart';

/// Full-screen phone search — the entry point of the daily workflow:
/// type the phone → confirm the customer → add a record.
class SearchCustomerPage extends StatefulWidget {
  const SearchCustomerPage({super.key, this.forRecord = false, this.initialQuery});

  /// When true, picking a customer opens "Add record" directly.
  final bool forRecord;
  final String? initialQuery;

  @override
  State<SearchCustomerPage> createState() => _SearchCustomerPageState();
}

class _SearchCustomerPageState extends State<SearchCustomerPage> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  bool _numeric = true;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').isNotEmpty) {
      context.read<CustomerSearchCubit>().queryChanged(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(Customer c) {
    if (widget.forRecord && !c.isArchived) {
      context.pushReplacement(Routes.addRecord(c.id, thenProfile: true), extra: c);
    } else {
      context.pushReplacement(Routes.customer(c.id), extra: c);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(widget.forRecord ? l.searchForRecordTitle : l.searchTitle)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
              child: TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: _numeric ? TextInputType.phone : TextInputType.text,
                textInputAction: TextInputAction.search,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: _numeric ? 1 : 0),
                onChanged: (v) {
                  context.read<CustomerSearchCubit>().queryChanged(v);
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: _numeric ? l.searchHint : l.searchByNameHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          tooltip: l.commonClear,
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _controller.clear();
                            context.read<CustomerSearchCubit>().queryChanged('');
                            setState(() {});
                          },
                        ),
                      IconButton(
                        tooltip: l.searchByNameHint,
                        icon: Icon(_numeric ? Icons.keyboard_rounded : Icons.dialpad_rounded),
                        onPressed: () => setState(() => _numeric = !_numeric),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<CustomerSearchCubit, CustomerSearchState>(
                builder: (context, state) => switch (state.status) {
                  SearchStatus.idle => EmptyView(
                    icon: Icons.phone_iphone_rounded,
                    title: l.searchTitle,
                    message: l.searchTypeMore,
                  ),
                  SearchStatus.loading when state.results.isEmpty => const LoadingView(),
                  SearchStatus.failure => ErrorView(
                    failure: state.failure!,
                    onRetry: () => context.read<CustomerSearchCubit>().retry(),
                  ),
                  SearchStatus.notFound => EmptyView(
                    icon: Icons.person_off_rounded,
                    title: l.searchNotFoundTitle,
                    message: l.searchNotFoundBody(state.query.trim()),
                    action: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
                      onPressed: () => context.pushReplacement(
                        Routes.newCustomer(
                          phone: PhoneNumber.looksLikeDigits(state.query) ? PhoneNumber.normalize(state.query) : null,
                          thenRecord: widget.forRecord,
                        ),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text(l.searchAddNew),
                    ),
                  ),
                  _ => _Results(state: state, onOpen: _open),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.onOpen});

  final CustomerSearchState state;
  final ValueChanged<Customer> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final digits = PhoneNumber.looksLikeDigits(state.query) ? PhoneNumber.normalize(state.query) : null;
    return Column(
      children: [
        if (state.status == SearchStatus.loading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.searchResults(state.results.length),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        if (state.results.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l.searchSelectHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.results.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) =>
                CustomerTile(customer: state.results[i], highlight: digits, onTap: () => onOpen(state.results[i])),
          ),
        ),
      ],
    );
  }
}
