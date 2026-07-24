import 'package:flutter/material.dart';

enum BallSkin {
  classic,
  neonGlow,
  bubble,
  fireball,
  disco,
}

class Ball {
  Offset position;
  Offset velocity;
  final double radius;
  final Color color;
  final BallSkin skin;

  // Squash and stretch parameters for a squishy feel!
  double squashX = 1.0;
  double squashY = 1.0;
  double squashTimer = 0.0;

  // Beautiful trail positions for rendering neon glow lines
  final List<Offset> trail = [];
  static const int maxTrailLength = 15;

  // Custom hue rotation for disco skin
  double hueRotation = 0.0;

  Ball({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.color,
    this.skin = BallSkin.classic,
  }) {
    hueRotation = color.computeLuminance() * 360;
  }

  void updateTrail() {
    trail.add(position);
    if (trail.length > maxTrailLength) {
      trail.removeAt(0);
    }
  }

  void applySquash(double targetX, double targetY) {
    squashX = targetX;
    squashY = targetY;
    squashTimer = 1.0; // Decay timer starting at max
  }

  void decaySquash(double dt) {
    if (squashTimer > 0) {
      squashTimer -= dt * 6.0; // Quick bounce-back
      if (squashTimer < 0) squashTimer = 0;
      // Interpolate back to 1.0
      squashX = squashX + (1.0 - squashX) * (1.0 - squashTimer);
      squashY = squashY + (1.0 - squashY) * (1.0 - squashTimer);
    } else {
      squashX = 1.0;
      squashY = 1.0;
    }
  }
}
