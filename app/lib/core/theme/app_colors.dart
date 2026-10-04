import 'package:flutter/material.dart';

/// Sanad colour tokens. Blue is the brand colour; status colours are used
/// sparingly and always paired with an icon or label (never colour alone).
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF1A56DB);
  static const primaryDark = Color(0xFF1E3A8A);
  static const primaryLight = Color(0xFF3F83F8);
  static const primarySoft = Color(0xFFE8F0FE);
  static const primarySofter = Color(0xFFF3F7FF);

  // Neutrals
  static const background = Color(0xFFF5F7FB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF1F4F9);
  static const border = Color(0xFFE2E8F0);
  static const divider = Color(0xFFEDF1F7);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF64748B);

  // Status
  static const success = Color(0xFF15803D);
  static const successSoft = Color(0xFFE7F6EC);
  static const warning = Color(0xFFB45309);
  static const warningSoft = Color(0xFFFEF3E2);
  static const error = Color(0xFFDC2626);
  static const errorSoft = Color(0xFFFDECEC);
  static const info = Color(0xFF0E7490);
  static const infoSoft = Color(0xFFE3F5F8);

  // Payment accents
  static const cash = Color(0xFF15803D);
  static const electronic = Color(0xFF6D28D9);
  static const electronicSoft = Color(0xFFF1EAFE);

  static const heroGradient = LinearGradient(
    colors: [primaryDark, primary],
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
  );
}
