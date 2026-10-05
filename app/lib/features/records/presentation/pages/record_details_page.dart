import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/service_record.dart';
import '../cubit/record_details_cubit.dart';
import '../widgets/record_widgets.dart';

class RecordDetailsPage extends StatelessWidget {
  const RecordDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocConsumer<RecordDetailsCubit, RecordDetailsState>(
      listenWhen: (a, b) => !a.archived && b.archived,
      listener: (context, state) {
        context.showSuccess(l.recordArchived);
        context.pop(true);
      },
      builder: (context, state) {
        final record = state.record;
        return Scaffold(
          appBar: AppBar(
            title: Text(l.recordDetailsTitle),
            actions: [
              if (record != null)
                IconButton(
                  tooltip: l.commonEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final updated = await context.push<ServiceRecord>(Routes.editRecord(record.id), extra: record);
                    if (updated != null && context.mounted) context.read<RecordDetailsCubit>().replace(updated);
                  },
                ),
              if (record != null)
                IconButton(
                  tooltip: l.archiveRecord,
                  icon: const Icon(Icons.archive_outlined),
                  onPressed: state.busy ? null : () => _archive(context),
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

  Future<void> _archive(BuildContext context) async {
    final l = context.l10n;
    final ok = await context.confirm(
      title: l.archiveRecord,
      message: l.archiveRecordConfirm,
      confirmLabel: l.archiveRecord,
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
                    if (record.isImported)
                      StatusChip(
                        label: l.recordImported,
                        icon: Icons.upload_file_rounded,
                        color: AppColors.info,
                        background: AppColors.infoSoft,
                      ),
                  ],
                ),
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
                value: record.customerName,
                trailing: IconButton(
                  tooltip: l.openCustomer,
                  icon: const Icon(Icons.open_in_new_rounded, color: AppColors.primary),
                  onPressed: () => context.push(Routes.customer(record.customerId)),
                ),
              ),
              if (record.customerPhone != null)
                InfoRow(icon: Icons.phone_outlined, label: l.fieldPhone, value: record.customerPhone!),
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
