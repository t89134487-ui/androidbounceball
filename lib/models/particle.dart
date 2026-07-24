import 'package:flutter/material.dart';

class Particle {
  Offset position;
  Offset velocity;
  final Color color;
  final double maxLifespan;
  double lifespan; // 1.0 down to 0.0
  final double size;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    this.maxLifespan = 0.8,
    required this.size,
  }) : lifespan = maxLifespan;

  void update(double dt) {
    position += velocity * dt;
    // Add gentle gravity and air resistance to particles
    velocity = Offset(velocity.dx * 0.98, velocity.dy * 0.98 + 40.0 * dt);
    lifespan -= dt;
  }

  bool get isDead => lifespan <= 0;
}
