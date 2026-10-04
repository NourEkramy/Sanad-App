import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/text_normalizer.dart';
import 'l10n.dart';

class PickerItem<T> {
  const PickerItem({required this.value, required this.label, this.subtitle, this.trailing});

  final T value;
  final String label;
  final String? subtitle;
  final String? trailing;
}

/// Bottom sheet with a search box for picking from long lists (nurses,
/// services, areas). Optionally offers "Add …" for a value that is missing.
///
/// Returns the picked value, or the result of [onAddNew].
Future<T?> showSearchablePicker<T>({
  required BuildContext context,
  required String title,
  required List<PickerItem<T>> items,
  T? selected,
  String? addNewLabel,
  Future<T?> Function(String query)? onAddNew,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _PickerSheet<T>(title: title, items: items, selected: selected, addNewLabel: addNewLabel, onAddNew: onAddNew),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({required this.title, required this.items, this.selected, this.addNewLabel, this.onAddNew});

  final String title;
  final List<PickerItem<T>> items;
  final T? selected;
  final String? addNewLabel;
  final Future<T?> Function(String query)? onAddNew;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _query = TextEditingController();
  bool _adding = false;

  List<PickerItem<T>> get _filtered {
    final q = TextNormalizer.key(_query.text);
    if (q.isEmpty) return widget.items;
    return widget.items.where((i) => TextNormalizer.key(i.label).contains(q)).toList();
  }

  bool get _exactMatch => widget.items.any((i) => TextNormalizer.sameName(i.label, _query.text));

  Future<void> _add() async {
    setState(() => _adding = true);
    final created = await widget.onAddNew!(_query.text.trim());
    if (!mounted) return;
    setState(() => _adding = false);
    if (created != null) Navigator.pop(context, created);
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final canAdd = widget.onAddNew != null;
    final typed = _query.text.trim();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, style: theme.textTheme.titleLarge)),
                  IconButton(
                    tooltip: context.l10n.commonClose,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                controller: _query,
                autofocus: widget.items.length > 8,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.l10n.pickerSearch,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.l10n.commonClear,
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(_query.clear),
                        ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (canAdd)
              ListTile(
                leading: _adding
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Icon(Icons.add_circle_rounded, color: AppColors.primary),
                title: Text(
                  typed.isNotEmpty && !_exactMatch ? context.l10n.pickerAddNamed(typed) : widget.addNewLabel ?? '',
                  style: theme.textTheme.titleSmall?.copyWith(color: AppColors.primary),
                ),
                onTap: _adding ? null : _add,
              ),
            const Divider(),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        context.l10n.pickerNoResults,
                        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(indent: AppSpacing.md, endIndent: AppSpacing.md),
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final isSelected = item.value == widget.selected;
                        return ListTile(
                          minTileHeight: 56,
                          title: Text(item.label, style: theme.textTheme.bodyLarge),
                          subtitle: item.subtitle == null ? null : Text(item.subtitle!),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.trailing != null)
                                Text(
                                  item.trailing!,
                                  style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textSecondary),
                                ),
                              if (isSelected) ...[
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                              ],
                            ],
                          ),
                          selected: isSelected,
                          selectedTileColor: AppColors.primarySofter,
                          onTap: () => Navigator.pop(context, item.value),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
