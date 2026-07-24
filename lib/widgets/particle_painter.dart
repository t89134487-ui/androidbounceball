import 'package:flutter/material.dart';
import '../models/particle.dart';

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  static final Paint _particlePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0)..style = PaintingStyle.fill;

  ParticlePainter({
    required this.particles,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < particles.length; i++) {
      final p = particles[i];
      final double alpha = p.lifespan / p.maxLifespan;

      _particlePaint.color = p.color.withAlpha((alpha * 255).round());
      canvas.drawCircle(p.position, p.size * alpha, _particlePaint);

      _glowPaint.color = p.color.withAlpha((alpha * 0.3 * 255).round());
      canvas.drawCircle(p.position, p.size * alpha * 2.5, _glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) {
    return true;
  }
}
