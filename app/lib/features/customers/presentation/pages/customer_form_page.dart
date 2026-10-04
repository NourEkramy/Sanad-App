import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/failure_messages.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/searchable_picker.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/customer.dart';
import '../cubit/customer_form_cubit.dart';
import '../widgets/customer_widgets.dart';

/// Add or edit a customer. Required: name, phone, area.
class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({super.key, this.editing, this.initialPhone, this.thenAddRecord = false});

  final Customer? editing;
  final String? initialPhone;

  /// Continue straight to "Add record" after saving (phone-search flow).
  final bool thenAddRecord;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  late final _name = TextEditingController(text: widget.editing?.fullName);
  late final _phone = TextEditingController(text: widget.editing?.phone ?? widget.initialPhone);
  late final _address = TextEditingController(text: widget.editing?.address);
  late final _notes = TextEditingController(text: widget.editing?.notes);

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    context.read<CustomerFormCubit>().submit(
      fullName: _name.text,
      phone: _phone.text,
      address: _address.text,
      notes: _notes.text,
    );
  }

  Future<void> _pickArea(CustomerFormState state) async {
    final l = context.l10n;
    final cubit = context.read<CustomerFormCubit>();
    final picked = await showSearchablePicker<String>(
      context: context,
      title: l.areaPickerTitle,
      selected: state.areaId,
      addNewLabel: l.areaAddNew,
      items: [
        for (final a in state.areas.where((a) => a.isActive || a.id == state.areaId))
          PickerItem(value: a.id, label: a.name),
      ],
      onAddNew: (query) async {
        final name = query.isNotEmpty ? query : await _askAreaName();
        if (name == null || name.trim().isEmpty) return null;
        final added = await cubit.addArea(name);
        if (added == null) {
          if (mounted && cubit.state.failure != null) context.showFailure(cubit.state.failure!);
          return null;
        }
        final (area, existed) = added;
        if (mounted) context.showSuccess(existed ? l.areaExisting(area.name) : l.areaCreated(area.name));
        return area.id;
      },
    );
    if (picked != null) cubit.selectArea(picked);
  }

  Future<String?> _askAreaName() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.areaNewTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.areaName),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.l10n.commonAdd),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _showDuplicate(Customer existing) async {
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.info_rounded, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(l.customerExistsTitle, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l.customerExistsBody, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            CustomerSummaryCard(customer: existing),
            if (existing.isArchived) ...[
              const SizedBox(height: AppSpacing.sm),
              InlineBanner.warning(message: l.customerExistsArchived),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (!existing.isArchived && widget.editing == null) ...[
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, 'record'),
                icon: const Icon(Icons.playlist_add_rounded),
                label: Text(l.actionAddRecord),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            OutlinedButton(onPressed: () => Navigator.pop(context, 'view'), child: Text(l.viewCustomer)),
          ],
        ),
      ),
    );
    if (!mounted) return;
    context.read<CustomerFormCubit>().dismissDuplicate();
    switch (action) {
      case 'record':
        context.pushReplacement(Routes.addRecord(existing.id, thenProfile: true), extra: existing);
      case 'view':
        context.pushReplacement(Routes.customer(existing.id), extra: existing);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editing = widget.editing != null;
    return BlocConsumer<CustomerFormCubit, CustomerFormState>(
      listenWhen: (a, b) => a.status != b.status || (b.failure != a.failure && b.failure is! ValidationFailure),
      listener: (context, state) {
        switch (state.status) {
          case CustomerFormStatus.duplicate:
            _showDuplicate(state.existing!);
          case CustomerFormStatus.saved:
            final customer = state.saved!;
            if (editing) {
              context.showSuccess(l.customerUpdated);
              context.canPop() ? context.pop(customer) : context.go(Routes.customer(customer.id));
            } else if (widget.thenAddRecord) {
              context.showSuccess(l.customerSavedTitle);
              context.pushReplacement(Routes.addRecord(customer.id, thenProfile: true), extra: customer);
            } else {
              context.pushReplacement(Routes.customerSaved(customer.id), extra: customer);
            }
          case CustomerFormStatus.editing when state.failure != null && state.failure is! ValidationFailure:
            context.showFailure(state.failure!);
          default:
            break;
        }
      },
      builder: (context, state) {
        final failure = state.failure;
        return Scaffold(
          appBar: AppBar(title: Text(editing ? l.editCustomerTitle : l.addCustomerTitle)),
          body: SafeArea(
            child: ListView(
              padding: AppSpacing.page,
              children: [
                AppTextField(
                  controller: _name,
                  label: l.fieldFullName,
                  prefixIcon: Icons.person_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofocus: !editing && (widget.initialPhone?.isNotEmpty ?? false),
                  errorText: context.fieldError(failure, 'fullName'),
                  onChanged: (_) => context.read<CustomerFormCubit>().fieldEdited('fullName'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phone,
                  label: l.fieldPhone,
                  helper: l.fieldPhoneHelper,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [PhoneInputFormatter()],
                  textDirection: TextDirection.ltr,
                  autofocus: !editing && (widget.initialPhone?.isEmpty ?? true),
                  errorText: context.fieldError(failure, 'phone'),
                  suffix: _phone.text.isNotEmpty && PhoneNumber.isValid(_phone.text)
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                      : null,
                  onChanged: (_) {
                    context.read<CustomerFormCubit>().fieldEdited('phone');
                    setState(() {});
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                PickerField(
                  label: l.fieldArea,
                  hint: l.fieldAreaHint,
                  icon: Icons.place_outlined,
                  value: state.selectedArea?.name,
                  errorText: context.fieldError(failure, 'areaId'),
                  trailing: state.areasLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                  onTap: state.areasLoading ? null : () => _pickArea(state),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _address,
                  label: l.fieldAddress,
                  optional: true,
                  prefixIcon: Icons.home_outlined,
                  maxLines: 3,
                  minLines: 1,
                  errorText: context.fieldError(failure, 'address'),
                  onChanged: (_) => context.read<CustomerFormCubit>().fieldEdited('address'),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _notes,
                  label: l.fieldNotes,
                  optional: true,
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 4,
                  minLines: 1,
                  errorText: context.fieldError(failure, 'notes'),
                  onChanged: (_) => context.read<CustomerFormCubit>().fieldEdited('notes'),
                ),
              ],
            ),
          ),
          bottomNavigationBar: BottomAction(
            child: PrimaryButton(
              label: editing ? l.commonSave : l.saveCustomer,
              icon: Icons.check_rounded,
              loading: state.status == CustomerFormStatus.saving,
              onPressed: _submit,
            ),
          ),
        );
      },
    );
  }
}

/// Success state after creating a customer, with the three next steps.
class CustomerSavedPage extends StatelessWidget {
  const CustomerSavedPage({super.key, required this.customer});
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 48, color: AppColors.success),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l.customerSavedTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l.customerSavedBody(customer.fullName),
                    style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CustomerSummaryCard(customer: customer),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton.icon(
                    onPressed: () =>
                        context.pushReplacement(Routes.addRecord(customer.id, thenProfile: true), extra: customer),
                    icon: const Icon(Icons.playlist_add_rounded),
                    label: Text(l.actionAddRecord),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => context.pushReplacement(Routes.customer(customer.id), extra: customer),
                    icon: const Icon(Icons.person_outline_rounded),
                    label: Text(l.viewCustomer),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(onPressed: () => context.go(Routes.home), child: Text(l.backToHome)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
