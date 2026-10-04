import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../../core/files/file_gateway.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/dates.dart';
import '../../../core/widgets/app_fields.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/app_localizations.dart';
import '../../records/domain/entities/service_record.dart';
import '../domain/excel_usecases.dart';
import '../domain/export/export_models.dart';

enum ExportPeriod { all, thisMonth, lastMonth, custom }

class ExportState extends Equatable {
  const ExportState({
    this.period = ExportPeriod.all,
    this.from,
    this.to,
    this.sheets = const {...ExportSheet.values},
    this.working = false,
    this.file,
    this.failure,
  });

  final ExportPeriod period;
  final DateTime? from;
  final DateTime? to;
  final Set<ExportSheet> sheets;
  final bool working;
  final ExportFile? file;
  final Failure? failure;

  ExportState copyWith({
    ExportPeriod? period,
    DateTime? Function()? from,
    DateTime? Function()? to,
    Set<ExportSheet>? sheets,
    bool? working,
    ExportFile? Function()? file,
    Failure? Function()? failure,
  }) => ExportState(
    period: period ?? this.period,
    from: from != null ? from() : this.from,
    to: to != null ? to() : this.to,
    sheets: sheets ?? this.sheets,
    working: working ?? this.working,
    file: file != null ? file() : this.file,
    failure: failure != null ? failure() : this.failure,
  );

  @override
  List<Object?> get props => [period, from, to, sheets, working, file, failure];
}

class ExportCubit extends Cubit<ExportState> {
  ExportCubit(this._export, this._files) : super(const ExportState());

  final ExportWorkbook _export;
  final FileGateway _files;

  void setPeriod(ExportPeriod period, {DateTime? from, DateTime? to}) {
    final today = Dates.today();
    final (f, t) = switch (period) {
      ExportPeriod.all => (null, null),
      ExportPeriod.thisMonth => (DateTime(today.year, today.month), today),
      ExportPeriod.lastMonth => (DateTime(today.year, today.month - 1), DateTime(today.year, today.month, 0)),
      ExportPeriod.custom => (from, to),
    };
    emit(state.copyWith(period: period, from: () => f, to: () => t, file: () => null, failure: () => null));
  }

  void toggleSheet(ExportSheet sheet) {
    final sheets = {...state.sheets};
    if (!sheets.remove(sheet)) sheets.add(sheet);
    emit(state.copyWith(sheets: sheets, file: () => null, failure: () => null));
  }

  Future<void> create(ExportLabels labels) async {
    emit(state.copyWith(working: true, file: () => null, failure: () => null));
    final result = await _export(ExportRequest(from: state.from, to: state.to, sheets: state.sheets), labels);
    if (isClosed) return;
    emit(
      result.fold(
        (f) => state.copyWith(working: false, failure: () => f),
        (file) => state.copyWith(working: false, file: () => file),
      ),
    );
    if (result.valueOrNull case final file?) await share(file);
  }

  Future<void> share(ExportFile file) async {
    try {
      await _files.shareFile(name: file.fileName, bytes: file.bytes);
    } catch (_) {
      if (!isClosed) emit(state.copyWith(failure: () => const FileFailure(FileFailureReason.writeFailed)));
    }
  }
}

/// Builds workbook labels in the current app language.
ExportLabels exportLabelsFor(AppLocalizations l) => ExportLabels(
  rtl: l.localeName.startsWith('ar'),
  sheetNames: {
    ExportSheet.records: l.recordsTitle,
    ExportSheet.customers: l.customersTitle,
    ExportSheet.nurses: l.nursesTitle,
    ExportSheet.services: l.servicesTitle,
    ExportSheet.areas: l.areasTitle,
  },
  recordHeaders: [
    l.exportRecordId,
    l.importField_customerName,
    l.importField_phone,
    l.fieldAddress,
    l.fieldArea,
    l.importField_patientName,
    l.fieldNurse,
    l.fieldService,
    '${l.fieldPrice} (${l.egp})',
    l.fieldPaymentMethod,
    l.importField_serviceDate,
    l.importField_serviceTime,
    l.fieldNotes,
    l.recordCreatedAt,
  ],
  customerHeaders: [
    'ID',
    l.fieldFullName,
    l.fieldPhone,
    l.fieldAddress,
    l.fieldArea,
    l.profileVisits,
    l.profileLastVisit,
    l.recordCreatedAt,
  ],
  nurseHeaders: ['ID', l.nurseName, l.fieldPhone, l.commonActive],
  serviceHeaders: ['ID', l.serviceName, '${l.serviceDefaultPrice} (${l.egp})', l.commonActive],
  areaHeaders: ['ID', l.areaName, l.commonActive],
  paymentLabels: {
    PaymentMethod.cash: l.paymentCash,
    PaymentMethod.electronic: l.paymentElectronic,
    PaymentMethod.unspecified: l.paymentUnspecified,
  },
  active: l.commonActive,
  inactive: l.commonInactive,
  variablePrice: l.serviceVariablePrice,
  total: l.exportSheetTotal,
);

class ExportPage extends StatelessWidget {
  const ExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return BlocConsumer<ExportCubit, ExportState>(
      listenWhen: (a, b) => a.failure != b.failure && b.failure != null,
      listener: (context, state) => context.showFailure(state.failure!),
      builder: (context, state) {
        final cubit = context.read<ExportCubit>();
        final periods = {
          ExportPeriod.all: l.exportAllTime,
          ExportPeriod.thisMonth: l.filterThisMonth,
          ExportPeriod.lastMonth: l.filterLastMonth,
          ExportPeriod.custom: state.period == ExportPeriod.custom && state.from != null
              ? '${fmt.shortDate(state.from!)} – ${fmt.shortDate(state.to!)}'
              : l.filterCustomRange,
        };
        final sheetLabels = {
          ExportSheet.records: l.exportSheetRecords,
          ExportSheet.customers: l.exportSheetCustomers,
          ExportSheet.nurses: l.exportSheetNurses,
          ExportSheet.services: l.exportSheetServices,
          ExportSheet.areas: l.exportSheetAreas,
        };
        return Scaffold(
          appBar: AppBar(title: Text(l.exportTitle)),
          body: ListView(
            padding: AppSpacing.page,
            children: [
              Text(
                l.exportIntro,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
              SectionHeader(l.exportPeriod),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final MapEntry(key: p, value: label) in periods.entries)
                    ChoiceChip(
                      label: Text(label),
                      selected: state.period == p,
                      onSelected: (_) async {
                        if (p != ExportPeriod.custom) return cubit.setPeriod(p);
                        final range = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: Dates.today(),
                        );
                        if (range != null) cubit.setPeriod(p, from: range.start, to: range.end);
                      },
                    ),
                ],
              ),
              SectionHeader(l.exportSheets),
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final MapEntry(key: sheet, value: label) in sheetLabels.entries)
                      CheckboxListTile(
                        value: state.sheets.contains(sheet),
                        onChanged: (_) => cubit.toggleSheet(sheet),
                        title: Text(label),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                  ],
                ),
              ),
              if (state.failure != null) ...[
                const SizedBox(height: AppSpacing.md),
                InlineBanner.error(message: context.failureMessage(state.failure!)),
              ],
              if (state.file case final file?) ...[
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.task_alt_rounded, color: AppColors.success),
                    title: Text(l.exportReady),
                    subtitle: Text(l.exportReadyBody(file.recordCount, file.fileName)),
                    trailing: IconButton(
                      tooltip: l.exportShare,
                      icon: const Icon(Icons.ios_share_rounded, color: AppColors.primary),
                      onPressed: () => cubit.share(file),
                    ),
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: BottomAction(
            child: PrimaryButton(
              label: state.working ? l.exportWorking : l.exportCreate,
              icon: Icons.file_download_outlined,
              loading: state.working,
              onPressed: state.sheets.isEmpty ? null : () => cubit.create(exportLabelsFor(l)),
            ),
          ),
        );
      },
    );
  }
}
