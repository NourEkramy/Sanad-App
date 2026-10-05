import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/local_time.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/failure_messages.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/searchable_picker.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../customers/presentation/widgets/customer_widgets.dart';
import '../../domain/entities/service_record.dart';
import '../cubit/record_form_cubit.dart';
import '../widgets/record_widgets.dart';

/// Add a service record: nurse → service → price → payment → date/time → save.
/// Everything has a sensible default so the common case is a few taps.
class RecordFormPage extends StatefulWidget {
  const RecordFormPage({super.key, this.thenProfile = false});

  /// Show the customer's profile after saving (flows that did not start on
  /// the profile), so the new record is immediately visible in the history.
  final bool thenProfile;

  @override
  State<RecordFormPage> createState() => _RecordFormPageState();
}

class _RecordFormPageState extends State<RecordFormPage> {
  final _price = TextEditingController();
  final _patient = TextEditingController();
  final _notes = TextEditingController();
  bool _initialised = false;
  bool _showMore = false;

  @override
  void dispose() {
    _price.dispose();
    _patient.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _sync(RecordFormState state) {
    final d = state.draft;
    if (_price.text != d.price) {
      _price.value = TextEditingValue(
        text: d.price,
        selection: TextSelection.collapsed(offset: d.price.length),
      );
    }
    if (!_initialised) {
      _patient.text = d.patientName ?? '';
      _notes.text = d.notes ?? '';
      _showMore = _patient.text.isNotEmpty || _notes.text.isNotEmpty;
      _initialised = true;
    }
  }

  Future<void> _pickNurse(RecordFormState state) async {
    final cubit = context.read<RecordFormCubit>();
    final l = context.l10n;
    final id = await showSearchablePicker<String>(
      context: context,
      title: l.fieldNurseHint,
      selected: state.draft.nurseId,
      addNewLabel: l.addNurse,
      items: [
        for (final n in state.nurses.where((n) => n.isActive || n.id == state.draft.nurseId))
          PickerItem(value: n.id, label: n.name, subtitle: n.isActive ? null : l.commonInactive),
      ],
      onAddNew: (q) async {
        if (q.trim().isEmpty) return null;
        return (await cubit.addNurse(q))?.id;
      },
    );
    if (id == null) return;
    final nurse = cubit.state.nurses.where((n) => n.id == id).firstOrNull;
    if (nurse != null) cubit.selectNurse(nurse);
  }

  Future<void> _pickService(RecordFormState state) async {
    final cubit = context.read<RecordFormCubit>();
    final l = context.l10n;
    final id = await showSearchablePicker<String>(
      context: context,
      title: l.fieldServiceHint,
      selected: state.draft.serviceId,
      addNewLabel: l.addService,
      items: [
        for (final s in state.services.where((s) => s.isActive || s.id == state.draft.serviceId))
          PickerItem(
            value: s.id,
            label: s.name,
            trailing: s.defaultPrice == null ? null : context.fmt.money(s.defaultPrice!),
          ),
      ],
      onAddNew: (q) async {
        if (q.trim().isEmpty) return null;
        return (await cubit.addService(q))?.id;
      },
    );
    if (id == null) return;
    final service = cubit.state.services.where((s) => s.id == id).firstOrNull;
    if (service != null) cubit.selectService(service);
  }

  Future<void> _pickDate(RecordFormState state) async {
    final today = Dates.today();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.draft.serviceDate ?? today,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null && mounted) context.read<RecordFormCubit>().dateChanged(picked);
  }

  Future<void> _pickTime(RecordFormState state) async {
    final t = state.draft.serviceTime ?? LocalTime.fromDateTime(DateTime.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: t.hour, minute: t.minute),
    );
    if (picked != null && mounted) context.read<RecordFormCubit>().timeChanged(LocalTime(picked.hour, picked.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<RecordFormCubit>();
    return BlocConsumer<RecordFormCubit, RecordFormState>(
      listenWhen: (a, b) => a.status != b.status || a.failure != b.failure || a.draft.price != b.draft.price,
      listener: (context, state) {
        _sync(state);
        if (state.status == RecordFormStatus.saved) {
          context.showSuccess(cubit.isEditing ? l.recordUpdated : l.recordSaved);
          if (widget.thenProfile) {
            context.go(Routes.customer(cubit.customer.id), extra: cubit.customer);
          } else if (context.canPop()) {
            context.pop(state.saved);
          } else {
            // Opened directly (deep link / web refresh).
            context.go(Routes.customer(cubit.customer.id));
          }
        } else if (state.failure != null && state.failure is! ValidationFailure) {
          context.showFailure(state.failure!);
        }
      },
      builder: (context, state) {
        if (state.status == RecordFormStatus.loading) {
          return Scaffold(
            appBar: AppBar(title: Text(l.addRecordTitle)),
            body: const LoadingView(),
          );
        }
        _sync(state);
        final d = state.draft;
        final failure = state.failure;
        final service = state.selectedService;
        return Scaffold(
          appBar: AppBar(title: Text(cubit.isEditing ? l.editRecordTitle : l.addRecordTitle)),
          body: SafeArea(
            child: ListView(
              padding: AppSpacing.page,
              children: [
                CustomerSummaryCard(customer: cubit.customer),
                if (state.restoredDraft) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InlineBanner(
                    message: l.draftRestored,
                    icon: Icons.restore_rounded,
                    action: TextButton(
                      onPressed: () async {
                        await cubit.discardDraft();
                        _patient.clear();
                        _notes.clear();
                      },
                      child: Text(l.discardDraft),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PickerField(
                  label: l.fieldNurse,
                  hint: l.fieldNurseHint,
                  icon: Icons.badge_outlined,
                  value: d.nurseName,
                  errorText: context.fieldError(failure, 'nurse'),
                  onTap: () => _pickNurse(state),
                ),
                const SizedBox(height: AppSpacing.md),
                PickerField(
                  label: l.fieldService,
                  hint: l.fieldServiceHint,
                  icon: Icons.medical_services_outlined,
                  value: d.serviceName,
                  errorText: context.fieldError(failure, 'service'),
                  onTap: () => _pickService(state),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _price,
                  label: l.fieldPrice,
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  helper: service?.defaultPrice != null
                      ? l.fieldPriceDefault(context.fmt.money(service!.defaultPrice!))
                      : l.fieldPriceHelper,
                  errorText: context.fieldError(failure, 'price'),
                  suffix: Padding(
                    padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        l.egp,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ),
                  onChanged: cubit.priceChanged,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(l.fieldPaymentMethod, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                _PaymentSelector(
                  value: d.paymentMethod,
                  onChanged: cubit.paymentChanged,
                  errorText: context.fieldError(failure, 'paymentMethod'),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: PickerField(
                        label: l.fieldDate,
                        icon: Icons.event_outlined,
                        value: d.serviceDate == null ? null : context.fmt.relativeDate(d.serviceDate!),
                        errorText: context.fieldError(failure, 'serviceDate'),
                        onTap: () => _pickDate(state),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PickerField(
                        label: l.fieldTime,
                        icon: Icons.schedule_outlined,
                        value: d.serviceTime == null ? null : context.fmt.time(d.serviceTime!),
                        errorText: context.fieldError(failure, 'serviceTime'),
                        onTap: () => _pickTime(state),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!_showMore)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _showMore = true),
                      icon: const Icon(Icons.add_rounded),
                      label: Text('${l.fieldNotes} / ${l.fieldPatientName}'),
                    ),
                  )
                else ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _patient,
                    label: l.fieldPatientName,
                    helper: l.fieldPatientHelper,
                    optional: true,
                    prefixIcon: Icons.person_outline_rounded,
                    onChanged: cubit.patientChanged,
                    errorText: context.fieldError(failure, 'patientName'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _notes,
                    label: l.fieldNotes,
                    optional: true,
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 4,
                    minLines: 2,
                    onChanged: cubit.notesChanged,
                    errorText: context.fieldError(failure, 'notes'),
                  ),
                ],
              ],
            ),
          ),
          bottomNavigationBar: BottomAction(
            child: PrimaryButton(
              label: cubit.isEditing ? l.commonSave : l.saveRecord,
              icon: Icons.check_rounded,
              loading: state.status == RecordFormStatus.saving,
              onPressed: () {
                FocusScope.of(context).unfocus();
                cubit.submit();
              },
            ),
          ),
        );
      },
    );
  }
}

/// Large two-option toggle: Cash / Electronic.
class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({required this.value, required this.onChanged, this.errorText});

  final PaymentMethod? value;
  final ValueChanged<PaymentMethod> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          for (final method in PaymentMethod.selectable) ...[
            Expanded(
              child: _PaymentOption(
                method: method,
                selected: value == method,
                hasError: errorText != null,
                onTap: () => onChanged(method),
              ),
            ),
            if (method != PaymentMethod.selectable.last) const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
      if (errorText != null)
        Padding(
          padding: const EdgeInsetsDirectional.only(start: AppSpacing.md, top: 6),
          child: Text(errorText!, style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
        ),
    ],
  );
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({required this.method, required this.selected, required this.hasError, required this.onTap});

  final PaymentMethod method;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = method.color;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? method.background : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.input,
          side: BorderSide(
            color: selected ? color : (hasError ? AppColors.error : AppColors.border),
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(borderRadius: AppRadius.input),
          onTap: onTap,
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : method.icon,
                  color: selected ? color : AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  method.label(context),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: selected ? color : AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
