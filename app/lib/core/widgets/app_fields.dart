import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'l10n.dart';

/// Labelled text field with consistent spacing and error display.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.autofocus = false,
    this.optional = false,
    this.enabled = true,
    this.autofillHints,
    this.textDirection,
    this.focusNode,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? errorText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final int? minLines;
  final bool obscureText;
  final bool autofocus;
  final bool optional;
  final bool enabled;
  final Iterable<String>? autofillHints;
  final TextDirection? textDirection;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focusNode,
    decoration: InputDecoration(
      labelText: optional ? '$label (${context.l10n.commonOptional})' : label,
      hintText: hint,
      helperText: errorText == null ? helper : null,
      helperMaxLines: 2,
      errorText: errorText,
      errorMaxLines: 3,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixIcon: suffix,
      alignLabelWithHint: maxLines > 1,
    ),
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    inputFormatters: inputFormatters,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    maxLines: obscureText ? 1 : maxLines,
    minLines: minLines,
    obscureText: obscureText,
    autofocus: autofocus,
    enabled: enabled,
    autofillHints: autofillHints,
    textDirection: textDirection,
  );
}

/// Read-only field that looks like an input and opens a picker when tapped.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.hint,
    this.icon,
    this.errorText,
    this.helper,
    this.trailing,
  });

  final String label;
  final String? value;
  final String? hint;
  final IconData? icon;
  final String? errorText;
  final String? helper;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.isNotEmpty;
    return Semantics(
      button: true,
      label: label,
      value: value,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.input,
        child: InputDecorator(
          isEmpty: !hasValue,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            errorText: errorText,
            helperText: errorText == null ? helper : null,
            helperMaxLines: 2,
            prefixIcon: icon == null ? null : Icon(icon),
            suffixIcon: trailing ?? const Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
            enabled: onTap != null,
          ),
          child: Text(
            hasValue ? value! : '',
            style: Theme.of(context).textTheme.bodyLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Primary call to action with a built-in loading state.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    child: loading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: AppSpacing.xs)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          ),
  );
}

/// Digits only (accepts Arabic-Indic digits by converting them).
class PhoneInputFormatter extends TextInputFormatter {
  static const _eastern = '٠١٢٣٤٥٦٧٨٩';

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final b = StringBuffer();
    for (final rune in newValue.text.runes) {
      final ch = String.fromCharCode(rune);
      final i = _eastern.indexOf(ch);
      if (i >= 0) {
        b.write(i);
      } else if (RegExp(r'[0-9+]').hasMatch(ch)) {
        b.write(ch);
      }
    }
    final text = b.toString();
    if (text.length > 14) return oldValue;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Primary action pinned to the bottom of form screens.
class BottomAction extends StatelessWidget {
  const BottomAction({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    elevation: 8,
    shadowColor: Colors.black26,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
        child: child,
      ),
    ),
  );
}
