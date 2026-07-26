import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  final Color themeColor;

  GridPainter({required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = themeColor.withAlpha((0.06 * 255).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Subtly glow center or corners
    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          themeColor.withAlpha((0.08 * 255).round()),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: (size.width > size.height ? size.width : size.height) * 0.7));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), centerGlow);
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) {
    return oldDelegate.themeColor != themeColor;
  }
}
