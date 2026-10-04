import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/entities/service_record.dart';
import '../../domain/repositories/record_repository.dart';
import '../cubit/sync_cubit.dart';
import '../widgets/record_widgets.dart';

class PendingRecordsCubit extends Cubit<List<ServiceRecord>?> {
  PendingRecordsCubit(this._store) : super(null);
  final PendingRecordStore _store;

  Future<void> load() async {
    final records = await _store.all();
    if (!isClosed) emit(records);
  }
}

/// Records saved on the device while offline, with manual sync/discard.
class PendingSyncPage extends StatelessWidget {
  const PendingSyncPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocListener<SyncCubit, SyncQueueState>(
      listenWhen: (a, b) => a.pending != b.pending || a.syncing != b.syncing,
      listener: (context, _) => context.read<PendingRecordsCubit>().load(),
      child: Scaffold(
        appBar: AppBar(title: Text(l.pendingTitle)),
        body: BlocBuilder<PendingRecordsCubit, List<ServiceRecord>?>(
          builder: (context, records) {
            if (records == null) return const LoadingView();
            if (records.isEmpty) {
              return EmptyView(icon: Icons.cloud_done_rounded, title: l.pendingEmpty);
            }
            final sync = context.watch<SyncCubit>().state;
            return ListView(
              padding: AppSpacing.page,
              children: [
                InlineBanner(message: l.pendingBody, icon: Icons.cloud_upload_rounded),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: sync.syncing
                      ? null
                      : () async {
                          final report = await context.read<SyncCubit>().syncNow();
                          if (!context.mounted || report == null) return;
                          if (report.remaining == 0 && report.failed == 0) context.showSuccess(l.syncDone);
                        },
                  icon: sync.syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(sync.syncing ? l.syncing : l.syncNow),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final r in records) ...[
                  RecordTile(
                    record: r,
                    showCustomer: true,
                    onTap: () async {
                      await context.push<bool>(Routes.record(r.id), extra: r);
                      if (context.mounted) await context.read<PendingRecordsCubit>().load();
                    },
                  ),
                  if (r.syncState == SyncState.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        l.recordSyncFailed,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.error),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
