import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_fields.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/import/column_mapping.dart';
import '../domain/import/import_plan.dart';
import 'import_cubit.dart';

extension ImportFieldLabel on ImportField {
  String label(AppLocalizations l) => switch (this) {
    ImportField.legacyRef => l.importField_legacyRef,
    ImportField.serviceDate => l.importField_serviceDate,
    ImportField.serviceTime => l.importField_serviceTime,
    ImportField.customerName => l.importField_customerName,
    ImportField.phone => l.importField_phone,
    ImportField.address => l.importField_address,
    ImportField.area => l.importField_area,
    ImportField.nurse => l.importField_nurse,
    ImportField.service => l.importField_service,
    ImportField.price => l.importField_price,
    ImportField.paymentMethod => l.importField_paymentMethod,
    ImportField.patientName => l.importField_patientName,
    ImportField.notes => l.importField_notes,
    ImportField.status => l.importField_status,
    ImportField.sanadId => l.importField_sanadId,
  };
}

String issueLabel(AppLocalizations l, String code) => switch (code) {
  'date_missing' => l.importIssue_datemissing,
  'date_invalid' => l.importIssue_dateinvalid,
  'price_missing' => l.importIssue_pricemissing,
  'price_invalid' => l.importIssue_priceinvalid,
  'customer_missing' => l.importIssue_customermissing,
  'date_ambiguous' => l.importIssue_dateambiguous,
  'time_missing' => l.importIssue_timemissing,
  'time_invalid' => l.importIssue_timeinvalid,
  'time_ambiguous' => l.importIssue_timeambiguous,
  'phone_invalid' => l.importIssue_phoneinvalid,
  'phone_shared' => l.importIssue_phoneshared,
  'nurse_missing' => l.importIssue_nursemissing,
  'service_missing' => l.importIssue_servicemissing,
  'area_missing' => l.importIssue_areamissing,
  'price_cleaned' => l.importIssue_pricecleaned,
  'payment_unknown' => l.importIssue_paymentunknown,
  'customer_details_changed' => l.importIssue_customerdetailschanged,
  _ => code,
};

class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocConsumer<ImportCubit, ImportState>(
      listenWhen: (a, b) => a.failure != b.failure && b.failure != null && b.failure is! ValidationFailure,
      listener: (context, state) => context.showFailure(state.failure!),
      builder: (context, state) => PopScope(
        canPop: state.step != ImportStep.committing,
        child: Scaffold(
          appBar: AppBar(title: Text(l.importTitle)),
          body: SafeArea(
            child: switch (state.step) {
              ImportStep.start => _Start(state: state),
              ImportStep.reading => LoadingView(message: l.importReading),
              ImportStep.columns || ImportStep.preparing => _Columns(state: state),
              ImportStep.preview || ImportStep.committing => _Preview(state: state),
              ImportStep.done => _Done(state: state),
            },
          ),
        ),
      ),
    );
  }
}

class _Start extends StatelessWidget {
  const _Start({required this.state});
  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<ImportCubit>();
    return ListView(
      padding: AppSpacing.page,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.table_view_rounded, color: AppColors.primary, size: 36),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l.importIntro,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: cubit.pickFile,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: Text(l.importChooseFile),
                ),
              ],
            ),
          ),
        ),
        if (state.failure != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineBanner.error(message: context.failureMessage(state.failure!)),
        ],
        _History(state: state),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.state});
  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<ImportCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l.importHistory),
        if (state.batchesLoading && state.batches.isEmpty)
          const Padding(padding: EdgeInsets.all(AppSpacing.md), child: LoadingView())
        else if (state.batches.isEmpty)
          Text(
            l.importHistoryEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          )
        else
          for (final b in state.batches)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Card(
                child: ListTile(
                  leading: Icon(
                    b.isRolledBack ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                    color: b.isRolledBack ? AppColors.textMuted : AppColors.success,
                  ),
                  title: Text(b.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(l.importBatchSummary(b.recordCount, context.fmt.dateTime(b.createdAt))),
                  trailing: b.isRolledBack
                      ? StatusChip(
                          label: l.importRolledBack,
                          color: AppColors.textSecondary,
                          background: AppColors.surfaceMuted,
                        )
                      : state.rollingBack == b.id
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(
                          style: TextButton.styleFrom(foregroundColor: AppColors.error),
                          onPressed: () async {
                            final ok = await context.confirm(
                              title: l.importRollback,
                              message: l.importRollbackConfirm(b.fileName),
                              confirmLabel: l.importRollback,
                              destructive: true,
                            );
                            if (!ok) return;
                            final failure = await cubit.rollback(b.id);
                            if (!context.mounted) return;
                            failure == null ? context.showSuccess(l.importRollbackDone) : context.showFailure(failure);
                          },
                          child: Text(l.importRollback),
                        ),
                ),
              ),
            ),
      ],
    );
  }
}

class _Columns extends StatelessWidget {
  const _Columns({required this.state});
  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<ImportCubit>();
    final workbook = state.workbook!;
    final mapping = state.mapping;
    final headers = mapping?.headers ?? const <int, String>{};
    final missing = mapping?.missingRequired ?? ImportField.values.where((f) => f.isRequired).toList();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpacing.page,
            children: [
              const _Steps(current: 1),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.primary),
                  title: Text(workbook.fileName),
                  trailing: TextButton(onPressed: cubit.reset, child: Text(l.importStartOver)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: state.sheetName,
                decoration: InputDecoration(labelText: l.importSheet, prefixIcon: const Icon(Icons.tab_outlined)),
                items: [
                  for (final s in workbook.sheets)
                    DropdownMenuItem(value: s.name, child: Text('${s.name}  (${s.nonEmptyRowCount})')),
                ],
                onChanged: (v) => v == null ? null : cubit.selectSheet(v),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l.importColumnsTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                l.importColumnsBody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              if (mapping != null) ...[
                const SizedBox(height: AppSpacing.xs),
                StatusChip(label: l.importHeaderRow(mapping.headerRow + 1), icon: Icons.table_rows_outlined),
              ],
              const SizedBox(height: AppSpacing.md),
              for (final field in ImportField.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: mapping?[field],
                    decoration: InputDecoration(
                      labelText: field.isRequired ? '${field.label(l)} *' : field.label(l),
                      errorText: missing.contains(field) ? l.validationRequired : null,
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.importNotMapped)),
                      for (final MapEntry(key: col, value: header) in headers.entries)
                        DropdownMenuItem(
                          value: col,
                          child: Text(header, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: mapping == null ? null : (v) => cubit.setColumn(field, v),
                  ),
                ),
            ],
          ),
        ),
        BottomAction(
          child: FilledButton.icon(
            onPressed: missing.isEmpty && state.step != ImportStep.preparing
                ? () => cubit.buildPreview(unspecifiedLabel: l.importUnspecifiedName)
                : null,
            icon: state.step == ImportStep.preparing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.preview_rounded),
            label: Text(
              missing.isEmpty
                  ? l.importBuildPreview
                  : l.importMissingRequired(missing.map((f) => f.label(l)).join('، ')),
            ),
          ),
        ),
      ],
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.state});
  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final cubit = context.read<ImportCubit>();
    final plan = state.plan!;
    final committing = state.step == ImportStep.committing;
    final warnings = plan.warningCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final errors = plan.errorCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpacing.page,
            children: [
              const _Steps(current: 2),
              const SizedBox(height: AppSpacing.md),
              Text(l.importPreviewTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              if (plan.committedImports > 0) ...[
                InlineBanner.warning(message: l.importAlreadyImported),
                const SizedBox(height: AppSpacing.sm),
              ],
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.7,
                children: [
                  StatTile(icon: Icons.receipt_long_rounded, label: l.importRecords, value: '${plan.records.length}'),
                  StatTile(
                    icon: Icons.block_rounded,
                    label: l.importSkipped,
                    value: '${plan.skipped.length}',
                    color: plan.skipped.isEmpty ? AppColors.success : AppColors.error,
                    background: plan.skipped.isEmpty ? AppColors.successSoft : AppColors.errorSoft,
                  ),
                  StatTile(
                    icon: Icons.person_add_alt_rounded,
                    label: l.importNewCustomers,
                    value: '${plan.newCustomers}',
                  ),
                  StatTile(
                    icon: Icons.how_to_reg_rounded,
                    label: l.importMatchedCustomers,
                    value: '${plan.matchedCustomers}',
                  ),
                  StatTile(
                    icon: Icons.payments_rounded,
                    label: l.importRevenue,
                    value: fmt.money(plan.totalRevenue),
                    color: AppColors.success,
                    background: AppColors.successSoft,
                  ),
                  StatTile(
                    icon: Icons.date_range_rounded,
                    label: l.importDateRange,
                    value: plan.firstDate == null
                        ? '—'
                        : '${fmt.shortDate(plan.firstDate!)} – ${fmt.shortDate(plan.lastDate!)}',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (plan.recordsWithoutPayment > 0) ...[
                InlineBanner(message: l.importNoPayment(plan.recordsWithoutPayment), icon: Icons.help_outline_rounded),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (plan.customersNeedingReview > 0)
                InlineBanner.warning(message: l.importReviewCustomers(plan.customersNeedingReview)),
              if (errors.isNotEmpty) ...[
                SectionHeader(l.importErrors),
                _IssueCard(
                  entries: errors,
                  color: AppColors.error,
                  rows: {
                    for (final e in errors)
                      e.key: plan.skipped.where((s) => s.issues.contains(e.key)).map((s) => s.rowNumber),
                  },
                ),
              ],
              if (warnings.isNotEmpty) ...[
                SectionHeader(l.importWarnings),
                _IssueCard(
                  entries: warnings,
                  color: AppColors.warning,
                  rows: {
                    for (final w in warnings)
                      w.key: plan.records.where((r) => r.warnings.contains(w.key)).map((r) => r.rowNumber),
                  },
                ),
              ],
              SectionHeader(l.importEntities),
              _EntityGroup(title: l.importNewAreas, entities: plan.areas),
              _EntityGroup(title: l.importNewNurses, entities: plan.nurses),
              _EntityGroup(title: l.importNewServices, entities: plan.services),
            ],
          ),
        ),
        BottomAction(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: committing ? null : cubit.backToColumns, child: Text(l.commonBack)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: committing || plan.records.isEmpty
                      ? null
                      : () async {
                          final ok = await context.confirm(
                            title: l.importConfirmTitle,
                            message: l.importConfirmBody,
                            confirmLabel: l.importConfirm(plan.records.length),
                          );
                          if (ok) await cubit.commit();
                        },
                  child: committing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(l.importRunning),
                          ],
                        )
                      : Text(l.importConfirm(plan.records.length)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({required this.entries, required this.color, required this.rows});

  final List<MapEntry<String, int>> entries;
  final Color color;
  final Map<String, Iterable<int>> rows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) const Divider(),
            ExpansionTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  '${e.value}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              title: Text(issueLabel(l, e.key), style: Theme.of(context).textTheme.bodyMedium),
              childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              expandedAlignment: AlignmentDirectional.centerStart,
              children: [
                Text(
                  l.importShowRows((rows[e.key] ?? const []).take(60).join(', ')),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EntityGroup extends StatelessWidget {
  const _EntityGroup({required this.title, required this.entities});
  final String title;
  final List<PlannedEntity> entities;

  @override
  Widget build(BuildContext context) {
    final newCount = entities.where((e) => !e.exists).length;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text('$title: $newCount / ${entities.length}'),
        childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final e in entities)
                Chip(
                  label: Text('${e.name} · ${e.rowCount}'),
                  avatar: e.exists ? null : const Icon(Icons.fiber_new_rounded, size: 18, color: AppColors.primary),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.state});
  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final r = state.result!;
    return ListView(
      padding: AppSpacing.page,
      children: [
        EmptyView(
          icon: Icons.task_alt_rounded,
          title: l.importDoneTitle,
          message: l.importDoneBody(r.createdRecords, r.createdCustomers, r.matchedCustomers),
          action: FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
            onPressed: context.read<ImportCubit>().reset,
            child: Text(l.commonDone),
          ),
        ),
        _History(state: state),
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final labels = [l.importStepFile, l.importStepColumns, l.importStepPreview];
    return Row(
      children: [
        for (final (i, label) in labels.indexed) ...[
          if (i > 0) Expanded(child: Divider(color: i <= current ? AppColors.primary : AppColors.border, thickness: 2)),
          Column(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= current ? AppColors.primary : AppColors.surfaceMuted,
                child: i < current
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : Text(
                        '${i + 1}',
                        style: TextStyle(color: i == current ? Colors.white : AppColors.textMuted, fontSize: 12),
                      ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ],
    );
  }
}
