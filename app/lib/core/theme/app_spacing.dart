import 'package:flutter/widgets.dart';

/// 4-pt spacing scale and shared radii.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  static const page = EdgeInsets.fromLTRB(md, md, md, xxl);

  /// Minimum touch target (Material guideline is 48; primary actions use 52).
  static const touchTarget = 48.0;
  static const buttonHeight = 52.0;
}

abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  static const card = BorderRadius.all(Radius.circular(lg));
  static const input = BorderRadius.all(Radius.circular(md));
  static const pill = BorderRadius.all(Radius.circular(999));
}
