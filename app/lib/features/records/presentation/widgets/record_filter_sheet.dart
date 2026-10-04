import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/l10n.dart';
import '../../../../core/widgets/searchable_picker.dart';
import '../../domain/entities/record_filter.dart';
import '../../domain/entities/service_record.dart';
import '../cubit/records_list_cubit.dart';
import 'record_widgets.dart';

/// Date range, nurse, service, area and payment filters.
Future<RecordFilter?> showRecordFilterSheet(BuildContext context, RecordsListState state) =>
    showModalBottomSheet<RecordFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(state: state),
    );

enum _Preset { any, today, week, month, lastMonth, custom }

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.state});
  final RecordsListState state;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RecordFilter _filter = widget.state.filter;

  _Preset get _preset {
    final f = _filter;
    if (f.from == null && f.to == null) return _Preset.any;
    final today = Dates.today();
    final (wFrom, wTo) = _range(_Preset.week);
    final (mFrom, mTo) = _range(_Preset.month);
    final (lFrom, lTo) = _range(_Preset.lastMonth);
    if (f.from == today && f.to == today) return _Preset.today;
    if (f.from == wFrom && f.to == wTo) return _Preset.week;
    if (f.from == mFrom && f.to == mTo) return _Preset.month;
    if (f.from == lFrom && f.to == lTo) return _Preset.lastMonth;
    return _Preset.custom;
  }

  static (DateTime?, DateTime?) _range(_Preset p) {
    final today = Dates.today();
    return switch (p) {
      _Preset.any => (null, null),
      _Preset.today => (today, today),
      // Weeks start on Saturday in Egypt.
      _Preset.week => (today.subtract(Duration(days: (today.weekday + 1) % 7)), today),
      _Preset.month => (DateTime(today.year, today.month), today),
      _Preset.lastMonth => (DateTime(today.year, today.month - 1), DateTime(today.year, today.month, 0)),
      _Preset.custom => (null, null),
    };
  }

  Future<void> _select(_Preset p) async {
    if (p == _Preset.custom) {
      final today = Dates.today();
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: today,
        initialDateRange: _filter.from != null && _filter.to != null
            ? DateTimeRange(start: _filter.from!, end: _filter.to!)
            : null,
      );
      if (picked == null) return;
      setState(() => _filter = _filter.copyWith(from: () => picked.start, to: () => picked.end));
      return;
    }
    final (from, to) = _range(p);
    setState(() => _filter = _filter.copyWith(from: () => from, to: () => to));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final s = widget.state;
    final theme = Theme.of(context);
    String? nameOf<T>(List<T> items, String? id, String Function(T) idOf, String Function(T) nameOf) =>
        id == null ? null : items.where((e) => idOf(e) == id).map(nameOf).firstOrNull;

    final presets = {
      _Preset.any: l.filterAnyDate,
      _Preset.today: l.commonToday,
      _Preset.week: l.filterThisWeek,
      _Preset.month: l.filterThisMonth,
      _Preset.lastMonth: l.filterLastMonth,
      _Preset.custom: _preset == _Preset.custom && _filter.from != null
          ? '${fmt.shortDate(_filter.from!)} – ${fmt.shortDate(_filter.to ?? _filter.from!)}'
          : l.filterCustomRange,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.recordsFilters, style: theme.textTheme.titleLarge)),
                TextButton(onPressed: () => setState(() => _filter = _filter.cleared()), child: Text(l.filterClearAll)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(l.filterDate, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final MapEntry(key: preset, value: label) in presets.entries)
                  ChoiceChip(label: Text(label), selected: _preset == preset, onSelected: (_) => _select(preset)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            PickerField(
              label: l.filterNurse,
              icon: Icons.badge_outlined,
              value: nameOf(s.nurses, _filter.nurseId, (n) => n.id, (n) => n.name) ?? l.filterAny,
              onTap: () async {
                final id = await showSearchablePicker<String>(
                  context: context,
                  title: l.filterNurse,
                  selected: _filter.nurseId ?? '',
                  items: [
                    PickerItem(value: '', label: l.filterAny),
                    for (final n in s.nurses) PickerItem(value: n.id, label: n.name),
                  ],
                );
                if (id != null) setState(() => _filter = _filter.copyWith(nurseId: () => id.isEmpty ? null : id));
              },
            ),
            const SizedBox(height: AppSpacing.md),
            PickerField(
              label: l.filterService,
              icon: Icons.medical_services_outlined,
              value: nameOf(s.services, _filter.serviceId, (x) => x.id, (x) => x.name) ?? l.filterAny,
              onTap: () async {
                final id = await showSearchablePicker<String>(
                  context: context,
                  title: l.filterService,
                  selected: _filter.serviceId ?? '',
                  items: [
                    PickerItem(value: '', label: l.filterAny),
                    for (final x in s.services) PickerItem(value: x.id, label: x.name),
                  ],
                );
                if (id != null) setState(() => _filter = _filter.copyWith(serviceId: () => id.isEmpty ? null : id));
              },
            ),
            const SizedBox(height: AppSpacing.md),
            PickerField(
              label: l.filterArea,
              icon: Icons.place_outlined,
              value: nameOf(s.areas, _filter.areaId, (a) => a.id, (a) => a.name) ?? l.filterAny,
              onTap: () async {
                final id = await showSearchablePicker<String>(
                  context: context,
                  title: l.filterArea,
                  selected: _filter.areaId ?? '',
                  items: [
                    PickerItem(value: '', label: l.filterAny),
                    for (final a in s.areas) PickerItem(value: a.id, label: a.name),
                  ],
                );
                if (id != null) setState(() => _filter = _filter.copyWith(areaId: () => id.isEmpty ? null : id));
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(l.filterPayment, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: Text(l.filterAny),
                  selected: _filter.paymentMethod == null,
                  onSelected: (_) => setState(() => _filter = _filter.copyWith(paymentMethod: () => null)),
                ),
                for (final m in PaymentMethod.values)
                  ChoiceChip(
                    avatar: Icon(m.icon, size: 18, color: m.color),
                    label: Text(m.label(context)),
                    selected: _filter.paymentMethod == m,
                    onSelected: (_) => setState(() => _filter = _filter.copyWith(paymentMethod: () => m)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(onPressed: () => Navigator.pop(context, _filter), child: Text(l.filterShowResults)),
          ],
        ),
      ),
    );
  }
}
