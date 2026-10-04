import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Sanad brand mark: a blue rounded tile with a white medical cross held by
/// a supporting arc ("سند" means support).
class SanadLogo extends StatelessWidget {
  const SanadLogo({super.key, this.size = 72, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sanad',
    image: true,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: onDark ? null : AppColors.heroGradient,
        color: onDark ? Colors.white : null,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: onDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: size * 0.3,
                  offset: Offset(0, size * 0.1),
                ),
              ],
      ),
      child: CustomPaint(painter: _MarkPainter(onDark ? AppColors.primary : Colors.white)),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()..color = color;
    // Cross
    final arm = w * 0.13;
    final len = w * 0.42;
    final center = Offset(w / 2, w * 0.44);
    final r = Radius.circular(arm * 0.35);
    canvas
      ..drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: arm, height: len), r), paint)
      ..drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: len, height: arm), r), paint);
    // Supporting arc
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round;
    final arcRect = Rect.fromCenter(center: Offset(w / 2, w * 0.5), width: w * 0.62, height: w * 0.56);
    canvas.drawArc(arcRect, 0.35, 2.44, false, stroke);
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}
