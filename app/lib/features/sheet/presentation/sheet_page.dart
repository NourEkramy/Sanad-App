import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_fields.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/sheet_usecases.dart';
import 'sheet_cubit.dart';

/// Where the connector script is bundled (same file as tools/google-sheets/Code.gs).
const connectorScriptAsset = 'assets/google_sheets/Code.gs';

class SheetPage extends StatelessWidget {
  const SheetPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.sheetTitle)),
      body: BlocBuilder<SheetCubit, SheetLinkState>(
        builder: (context, state) {
          if (!state.loaded) return const LoadingView();
          return ListView(
            padding: AppSpacing.page,
            children: [
              if (state.failure case final failure?) ...[
                InlineBanner.error(message: context.failureMessage(failure)),
                const SizedBox(height: AppSpacing.md),
              ],
              if (state.connection case final connection?)
                _ConnectionChoice(connection, busy: state.busy)
              else if (state.link != null)
                _Connected(state)
              else
                _Connect(state),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- connect

class _Connect extends StatefulWidget {
  const _Connect(this.state);
  final SheetLinkState state;

  @override
  State<_Connect> createState() => _ConnectState();
}

class _ConnectState extends State<_Connect> {
  final _link = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _link.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _copyScript() async {
    final l = context.l10n;
    final script = await DefaultAssetBundle.of(context).loadString(connectorScriptAsset);
    await Clipboard.setData(ClipboardData(text: script));
    if (mounted) context.showSuccess(l.sheetScriptCopied);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final state = widget.state;
    final steps = [l.sheetStep1, l.sheetStep2, l.sheetStep3, l.sheetStep4];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.table_chart_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(l.sheetIntro, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        SectionHeader(l.sheetSetupTitle),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, step) in steps.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primarySoft,
                        child: Text('${i + 1}', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(step, style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _copyScript,
                icon: const Icon(Icons.content_copy_rounded),
                label: Text(l.sheetCopyScript),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          controller: _link,
          label: l.sheetLinkLabel,
          hint: 'https://script.google.com/macros/s/…/exec',
          prefixIcon: Icons.link_rounded,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
        ),
        if (state.needsCode) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(message: l.sheetCodeNeeded, icon: Icons.key_rounded),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _code,
            label: l.sheetCodeLabel,
            prefixIcon: Icons.key_rounded,
            textDirection: TextDirection.ltr,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: l.sheetConnect,
          icon: Icons.link_rounded,
          loading: state.activity == SheetActivity.connecting,
          onPressed: () => context.read<SheetCubit>().connect(
            _link.text,
            code: state.needsCode && _code.text.trim().isNotEmpty ? _code.text : null,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- choice

class _ConnectionChoice extends StatelessWidget {
  const _ConnectionChoice(this.connection, {required this.busy});
  final SheetConnection connection;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<SheetCubit>();
    final plan = connection.plan;
    final loading = context.select<SheetCubit, bool>((c) => c.state.activity == SheetActivity.loading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: connection.pairing.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.sheetFound, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              if (plan != null) ...[
                InfoRow(icon: Icons.receipt_long_rounded, label: l.importRecords, value: '${plan.records.length}'),
                InfoRow(icon: Icons.groups_rounded, label: l.customersTitle, value: '${connection.customerCount}'),
                InfoRow(
                  icon: Icons.payments_rounded,
                  label: l.importRevenue,
                  value: context.fmt.money(plan.totalRevenue),
                ),
                if (plan.firstDate != null)
                  InfoRow(
                    icon: Icons.date_range_rounded,
                    label: l.importDateRange,
                    value: '${context.fmt.shortDate(plan.firstDate!)} – ${context.fmt.shortDate(plan.lastDate!)}',
                  ),
                if (plan.skipped.isNotEmpty)
                  InfoRow(icon: Icons.block_rounded, label: l.importSkipped, value: '${plan.skipped.length}'),
                if (plan.customersNeedingReview > 0)
                  InfoRow(
                    icon: Icons.person_search_rounded,
                    label: l.customersNeedsReview,
                    value: '${plan.customersNeedingReview}',
                  ),
              ] else
                InfoRow(icon: Icons.groups_rounded, label: l.customersTitle, value: '${connection.customerCount}'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!connection.phoneHasData) ...[
          PrimaryButton(
            label: l.sheetLoad,
            icon: Icons.download_rounded,
            loading: loading,
            onPressed: busy ? null : () => cubit.loadFromSheet(replace: false),
          ),
        ] else ...[
          InlineBanner.warning(message: l.sheetPhoneHasData),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: l.sheetUseSheetData,
            icon: Icons.download_rounded,
            loading: loading,
            onPressed: busy ? null : () => _confirmReplace(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _confirmKeep(context),
            icon: const Icon(Icons.upload_rounded),
            label: Text(l.sheetKeepPhoneData),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: busy ? null : cubit.cancelConnection, child: Text(l.commonCancel)),
      ],
    );
  }

  Future<void> _confirmReplace(BuildContext context) async {
    final l = context.l10n;
    final ok = await context.confirm(
      title: l.sheetUseSheetData,
      message: l.sheetReplaceConfirm,
      confirmLabel: l.sheetUseSheetData,
      destructive: true,
    );
    if (ok && context.mounted) await context.read<SheetCubit>().loadFromSheet(replace: true);
  }

  Future<void> _confirmKeep(BuildContext context) async {
    final l = context.l10n;
    final ok = await context.confirm(
      title: l.sheetKeepPhoneData,
      message: l.sheetKeepConfirm,
      confirmLabel: l.sheetKeepPhoneData,
    );
    if (ok && context.mounted) await context.read<SheetCubit>().keepPhoneData();
  }
}

// ---------------------------------------------------------------- connected

class _Connected extends StatelessWidget {
  const _Connected(this.state);
  final SheetLinkState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<SheetCubit>();
    final link = state.link!;
    final (icon, color, status) = switch (state) {
      SheetLinkState(activity: SheetActivity.syncing) => (Icons.sync_rounded, AppColors.primary, l.sheetUpdating),
      SheetLinkState(activity: SheetActivity.loading || SheetActivity.connecting) => (
        Icons.sync_rounded,
        AppColors.primary,
        l.sheetReading,
      ),
      SheetLinkState(failure: _?) => (Icons.sync_problem_rounded, AppColors.error, l.sheetNotUpdated),
      SheetLinkState(pending: final n) when n > 0 => (Icons.schedule_rounded, AppColors.warning, l.sheetWaiting(n)),
      _ => (Icons.check_circle_rounded, AppColors.success, l.sheetUpToDate),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(status, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color)),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.lg),
              InfoRow(icon: Icons.table_chart_outlined, label: l.sheetName, value: link.title),
              InfoRow(
                icon: Icons.history_rounded,
                label: l.sheetLastUpdate,
                value: link.lastSyncAt == null ? l.sheetNever : context.fmt.dateTime(link.lastSyncAt!),
              ),
              InfoRow(
                icon: Icons.tab_rounded,
                label: l.sheetWritesTo,
                value: [link.layout.visits.sheet, link.layout.cases.sheet, link.layout.lists.sheet].join(' · '),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: l.sheetUpdateNow,
          icon: Icons.sync_rounded,
          loading: state.activity == SheetActivity.syncing,
          onPressed: state.busy ? null : cubit.syncNow,
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: state.busy ? null : cubit.reloadFromSheet,
          icon: const Icon(Icons.download_rounded),
          label: Text(l.sheetReload),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: state.busy ? null : () => _confirmDisconnect(context),
          icon: const Icon(Icons.link_off_rounded),
          label: Text(l.sheetDisconnect),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(l.sheetOneWay, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final l = context.l10n;
    final ok = await context.confirm(
      title: l.sheetDisconnect,
      message: l.sheetDisconnectConfirm,
      confirmLabel: l.sheetDisconnect,
      destructive: true,
    );
    if (ok && context.mounted) await context.read<SheetCubit>().disconnect();
  }
}
