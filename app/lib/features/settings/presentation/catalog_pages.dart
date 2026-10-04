import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_fields.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/failure_messages.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/l10n.dart';
import '../../../core/widgets/state_views.dart';
import '../../areas/domain/entities/area.dart';
import '../../areas/domain/usecases/area_usecases.dart';
import '../../auth/domain/entities/app_user.dart';
import '../../auth/presentation/cubit/auth_cubit.dart';
import '../../care_services/domain/entities/care_service.dart';
import '../../care_services/domain/usecases/care_service_usecases.dart';
import '../../nurses/domain/entities/nurse.dart';
import '../../nurses/domain/usecases/nurse_usecases.dart';
import 'catalog_cubit.dart';

/// One generic screen layout shared by Nurses, Services and Areas.
class _CatalogScaffold<T> extends StatelessWidget {
  const _CatalogScaffold({
    required this.title,
    required this.emptyText,
    required this.addLabel,
    required this.icon,
    required this.onAdd,
    required this.itemBuilder,
  });

  final String title;
  final String emptyText;
  final String addLabel;
  final IconData icon;
  final VoidCallback? onAdd;
  final Widget Function(BuildContext, T) itemBuilder;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return BlocBuilder<CatalogCubit<T>, CatalogState<T>>(
      builder: (context, state) {
        final cubit = context.read<CatalogCubit<T>>();
        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: l.showInactive,
                isSelected: state.showInactive,
                icon: const Icon(Icons.visibility_off_outlined),
                selectedIcon: const Icon(Icons.visibility_rounded, color: AppColors.primary),
                onPressed: cubit.toggleInactive,
              ),
            ],
          ),
          floatingActionButton: onAdd == null
              ? null
              : FloatingActionButton.extended(
                  heroTag: 'catalog-fab-$title',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(addLabel),
                ),
          body: RefreshIndicator(
            onRefresh: cubit.load,
            child: switch (state) {
              CatalogState(loading: true, items: []) => const LoadingView(),
              CatalogState(items: [], :final failure?) => ListView(
                children: [ErrorView(failure: failure, onRetry: cubit.load)],
              ),
              CatalogState(items: []) => ListView(
                children: [EmptyView(icon: icon, title: emptyText)],
              ),
              _ => ListView.separated(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, 96),
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
                itemBuilder: (context, i) => itemBuilder(context, state.items[i]),
              ),
            },
          ),
        );
      },
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({required this.title, this.subtitle, required this.active, this.onTap, this.leading});

  final String title;
  final String? subtitle;
  final bool active;
  final VoidCallback? onTap;
  final IconData? leading;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minTileHeight: 64,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.card),
      leading: leading == null
          ? null
          : CircleAvatar(
              backgroundColor: active ? AppColors.primarySoft : AppColors.surfaceMuted,
              child: Icon(leading, color: active ? AppColors.primary : AppColors.textMuted, size: 20),
            ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: active ? null : AppColors.textMuted),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: active
          ? (onTap == null ? null : const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted))
          : StatusChip(
              label: context.l10n.commonInactive,
              color: AppColors.textSecondary,
              background: AppColors.surfaceMuted,
            ),
      onTap: onTap,
    ),
  );
}

/// Bottom-sheet form shared by the three catalogs.
Future<bool?> _showEditor(
  BuildContext context, {
  required String title,
  required List<_FieldSpec> fields,
  required bool? active,
  required Future<Result<Object>> Function(Map<String, String> values, bool? active) onSave,
  required String successMessage,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _Editor(title: title, fields: fields, active: active, onSave: onSave, successMessage: successMessage),
);

class _FieldSpec {
  const _FieldSpec(
    this.key,
    this.label, {
    this.initial,
    this.helper,
    this.keyboard,
    this.optional = false,
    this.ltr = false,
  });

  final String key;
  final String label;
  final String? initial;
  final String? helper;
  final TextInputType? keyboard;
  final bool optional;
  final bool ltr;
}

class _Editor extends StatefulWidget {
  const _Editor({
    required this.title,
    required this.fields,
    required this.active,
    required this.onSave,
    required this.successMessage,
  });

  final String title;
  final List<_FieldSpec> fields;
  final bool? active;
  final Future<Result<Object>> Function(Map<String, String> values, bool? active) onSave;
  final String successMessage;

  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  late final _controllers = {for (final f in widget.fields) f.key: TextEditingController(text: f.initial)};
  late bool? _active = widget.active;
  bool _saving = false;
  Failure? _failure;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (widget.active == true && _active == false) {
      final name = _controllers.values.first.text;
      final ok = await context.confirm(
        title: l.commonDeactivate,
        message: l.deactivateConfirm(name),
        confirmLabel: l.commonDeactivate,
        destructive: true,
      );
      if (!ok) return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    final result = await widget.onSave({for (final e in _controllers.entries) e.key: e.value.text}, _active);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failure = result.failureOrNull;
    });
    if (result.isSuccess) {
      context.showSuccess(widget.successMessage);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (_failure != null && _failure is! ValidationFailure) ...[
              InlineBanner.error(message: context.failureMessage(_failure!)),
              const SizedBox(height: AppSpacing.md),
            ],
            for (final (i, f) in widget.fields.indexed) ...[
              AppTextField(
                controller: _controllers[f.key],
                label: f.label,
                helper: f.helper,
                optional: f.optional,
                keyboardType: f.keyboard,
                autofocus: i == 0 && (f.initial ?? '').isEmpty,
                textDirection: f.ltr ? TextDirection.ltr : null,
                errorText: context.fieldError(_failure, f.key),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (_active != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.commonActive),
                subtitle: Text(l.statusActiveHelper),
                value: _active!,
                onChanged: (v) => setState(() => _active = v),
              ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(label: l.commonSave, loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- nurses

class NursesPage extends StatelessWidget {
  const NursesPage({super.key, required this.saveNurse});

  final SaveNurse saveNurse;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthCubit>();
    final canManage = auth.can(Permission.manageReferenceData);
    final canAdd = auth.can(Permission.createReferenceData);
    Future<void> edit(Nurse? nurse) async {
      final cubit = context.read<CatalogCubit<Nurse>>();
      final saved = await _showEditor(
        context,
        title: nurse == null ? l.addNurse : l.editNurse,
        active: nurse?.isActive,
        successMessage: l.nurseSaved,
        fields: [
          _FieldSpec('name', l.nurseName, initial: nurse?.name),
          _FieldSpec(
            'phone',
            l.fieldPhone,
            initial: nurse?.phone,
            keyboard: TextInputType.phone,
            optional: true,
            ltr: true,
          ),
          _FieldSpec('notes', l.fieldNotes, initial: nurse?.notes, optional: true),
        ],
        onSave: (v, active) =>
            saveNurse(existing: nurse, name: v['name']!, phone: v['phone'], notes: v['notes'], isActive: active),
      );
      if (saved ?? false) await cubit.load();
    }

    return _CatalogScaffold<Nurse>(
      title: l.nursesTitle,
      emptyText: l.nursesEmpty,
      addLabel: l.addNurse,
      icon: Icons.badge_rounded,
      onAdd: canAdd ? () => edit(null) : null,
      itemBuilder: (context, n) => _CatalogTile(
        leading: Icons.badge_outlined,
        title: n.name,
        subtitle: n.phone,
        active: n.isActive,
        onTap: canManage ? () => edit(n) : null,
      ),
    );
  }
}

// ------------------------------------------------------------------- services

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key, required this.saveService});

  final SaveCareService saveService;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthCubit>();
    final canManage = auth.can(Permission.manageReferenceData);
    final canAdd = auth.can(Permission.createReferenceData);
    Future<void> edit(CareService? service) async {
      final cubit = context.read<CatalogCubit<CareService>>();
      final saved = await _showEditor(
        context,
        title: service == null ? l.addService : l.editService,
        active: service?.isActive,
        successMessage: l.serviceSaved,
        fields: [
          _FieldSpec('name', l.serviceName, initial: service?.name),
          _FieldSpec(
            'defaultPrice',
            l.serviceDefaultPrice,
            initial: service?.defaultPrice?.format().replaceAll(',', ''),
            helper: l.serviceDefaultPriceHelper,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            optional: true,
            ltr: true,
          ),
        ],
        onSave: (v, active) =>
            saveService(existing: service, name: v['name']!, defaultPrice: v['defaultPrice'], isActive: active),
      );
      if (saved ?? false) await cubit.load();
    }

    return _CatalogScaffold<CareService>(
      title: l.servicesTitle,
      emptyText: l.servicesEmpty,
      addLabel: l.addService,
      icon: Icons.medical_services_rounded,
      onAdd: canAdd ? () => edit(null) : null,
      itemBuilder: (context, s) => _CatalogTile(
        leading: Icons.medical_services_outlined,
        title: s.name,
        subtitle: s.defaultPrice == null ? l.serviceVariablePrice : context.fmt.money(s.defaultPrice!),
        active: s.isActive,
        onTap: canManage ? () => edit(s) : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------- areas

class AreasPage extends StatelessWidget {
  const AreasPage({super.key, required this.createArea, required this.updateArea});

  final CreateArea createArea;
  final UpdateArea updateArea;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthCubit>();
    final canManage = auth.can(Permission.manageReferenceData);
    final canAdd = auth.can(Permission.createReferenceData);
    Future<void> edit(Area? area) async {
      final cubit = context.read<CatalogCubit<Area>>();
      final saved = await _showEditor(
        context,
        title: area == null ? l.addArea : l.editArea,
        active: area?.isActive,
        successMessage: l.areaSaved,
        fields: [_FieldSpec('name', l.areaName, initial: area?.name)],
        onSave: (v, active) => area == null
            ? createArea(v['name']!, known: cubit.state.items)
            : updateArea(area.copyWith(name: v['name'], isActive: active)),
      );
      if (saved ?? false) await cubit.load();
    }

    return _CatalogScaffold<Area>(
      title: l.areasTitle,
      emptyText: l.areasEmpty,
      addLabel: l.addArea,
      icon: Icons.map_rounded,
      onAdd: canAdd ? () => edit(null) : null,
      itemBuilder: (context, a) => _CatalogTile(
        leading: Icons.place_outlined,
        title: a.name,
        active: a.isActive,
        onTap: canManage ? () => edit(a) : null,
      ),
    );
  }
}
