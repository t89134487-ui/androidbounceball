import 'package:flutter/material.dart';
import '../models/particle.dart';

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final double alpha = p.lifespan / p.maxLifespan;

      // Beautiful star-burst particle paint with a circular glow
      final paint = Paint()
        ..color = p.color.withAlpha((alpha * 255).round())
        ..style = PaintingStyle.fill;

      // Draw particle as a glowing soft circle or tiny diamond
      canvas.drawCircle(p.position, p.size * alpha, paint);

      // Flare glow
      final glowPaint = Paint()
        ..color = p.color.withAlpha((alpha * 0.3 * 255).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      canvas.drawCircle(p.position, p.size * alpha * 2.5, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return true;
  }
}
