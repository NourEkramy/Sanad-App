import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/failure_messages.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../domain/entities/service_record.dart';
import '../cubit/record_details_cubit.dart';
import '../widgets/record_widgets.dart';

class RecordDetailsPage extends StatelessWidget {
  const RecordDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthCubit>();
    return BlocConsumer<RecordDetailsCubit, RecordDetailsState>(
      listenWhen: (a, b) => !a.archived && b.archived,
      listener: (context, state) {
        context.showSuccess(l.recordArchived);
        context.pop(true);
      },
      builder: (context, state) {
        final record = state.record;
        final pending = record != null && record.syncState != SyncState.synced;
        final canEdit = record != null && !pending && auth.can(Permission.editRecords);
        final canArchive = record != null && (pending || auth.can(Permission.archiveRecords));
        return Scaffold(
          appBar: AppBar(
            title: Text(l.recordDetailsTitle),
            actions: [
              if (canEdit)
                IconButton(
                  tooltip: l.commonEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final updated = await context.push<ServiceRecord>(Routes.editRecord(record.id), extra: record);
                    if (updated != null && context.mounted) context.read<RecordDetailsCubit>().replace(updated);
                  },
                ),
              if (canArchive)
                IconButton(
                  tooltip: pending ? l.pendingDiscard : l.archiveRecord,
                  icon: Icon(pending ? Icons.delete_outline_rounded : Icons.archive_outlined),
                  onPressed: state.busy ? null : () => _archive(context, pending: pending),
                ),
            ],
          ),
          body: switch (state) {
            RecordDetailsState(loading: true, record: null) => const LoadingView(),
            RecordDetailsState(record: null, :final failure?) => ErrorView(
              failure: failure,
              onRetry: () => context.read<RecordDetailsCubit>().load(),
            ),
            _ => _Body(record: record!),
          },
        );
      },
    );
  }

  Future<void> _archive(BuildContext context, {required bool pending}) async {
    final l = context.l10n;
    final ok = await context.confirm(
      title: pending ? l.pendingDiscard : l.archiveRecord,
      message: pending ? l.pendingDiscardConfirm : l.archiveRecordConfirm,
      confirmLabel: pending ? l.pendingDiscard : l.archiveRecord,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final failure = await context.read<RecordDetailsCubit>().archive();
    if (failure != null && context.mounted) context.showFailure(failure);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.record});
  final ServiceRecord record;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final theme = Theme.of(context);
    return ListView(
      padding: AppSpacing.page,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(record.serviceName, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(fmt.money(record.price), style: theme.textTheme.headlineSmall?.copyWith(color: AppColors.primary)),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    PaymentChip(record.paymentMethod),
                    SyncChip(record.syncState),
                    if (record.isImported)
                      StatusChip(
                        label: l.recordImported,
                        icon: Icons.upload_file_rounded,
                        color: AppColors.info,
                        background: AppColors.infoSoft,
                      ),
                  ],
                ),
                if (record.syncState == SyncState.failed && record.syncError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  InlineBanner.error(message: l.pendingFailedHint(context.ruleMessage(record.syncError!))),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionCard(
          child: Column(
            children: [
              InfoRow(
                icon: Icons.person_outline_rounded,
                label: l.recordCustomer,
                value: [record.customerName, if (record.customerPhone != null) record.customerPhone!].join('\n'),
                trailing: IconButton(
                  tooltip: l.openCustomer,
                  icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
                  onPressed: () => context.push(Routes.customer(record.customerId)),
                ),
              ),
              if (record.patientName != null)
                InfoRow(icon: Icons.personal_injury_outlined, label: l.recordPatient, value: record.patientName!),
              InfoRow(icon: Icons.badge_outlined, label: l.fieldNurse, value: record.nurseName),
              InfoRow(
                icon: Icons.event_outlined,
                label: l.recordWhen,
                value: [
                  fmt.date(record.serviceDate),
                  if (record.serviceTime != null) fmt.time(record.serviceTime!) else l.recordNoTime,
                ].join(' — '),
              ),
              if (record.areaName != null && record.areaName!.isNotEmpty)
                InfoRow(icon: Icons.place_outlined, label: l.recordAreaAtVisit, value: record.areaName!),
              if (record.customerAddress != null)
                InfoRow(icon: Icons.home_outlined, label: l.recordAddressAtVisit, value: record.customerAddress!),
              if (record.notes != null) InfoRow(icon: Icons.notes_rounded, label: l.fieldNotes, value: record.notes!),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SectionCard(
          child: Column(
            children: [
              InfoRow(
                icon: Icons.history_toggle_off_rounded,
                label: l.recordCreatedAt,
                value: fmt.dateTime(record.createdAt),
              ),
              if (record.legacyRef != null)
                InfoRow(icon: Icons.tag_rounded, label: l.recordLegacyRef, value: record.legacyRef!),
            ],
          ),
        ),
      ],
    );
  }
}
