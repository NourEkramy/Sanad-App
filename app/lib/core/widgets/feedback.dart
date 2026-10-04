import 'package:flutter/material.dart';

import '../errors/failure.dart';
import '../theme/app_colors.dart';
import 'failure_messages.dart';
import 'l10n.dart';

/// Snackbars and dialogs used for success/error feedback everywhere.
extension FeedbackX on BuildContext {
  void showSuccess(String message) => _snack(message, AppColors.success, Icons.check_circle_rounded);

  void showInfo(String message) => _snack(message, AppColors.primaryDark, Icons.info_rounded);

  void showWarning(String message) => _snack(message, AppColors.warning, Icons.cloud_off_rounded);

  void showFailure(Failure failure) => _snack(failureMessage(failure), AppColors.error, Icons.error_rounded);

  void _snack(String message, Color color, IconData icon) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: color,
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  /// Confirmation for destructive or important actions.
  Future<bool> confirm({
    required String title,
    required String message,
    String? confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(96, 44),
              backgroundColor: destructive ? AppColors.error : AppColors.primary,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel ?? context.l10n.commonConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
