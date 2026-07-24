import 'package:flutter/material.dart';

enum ObstacleType {
  circularBumper,
  rectangularPeg,
  vortex,
  teleporter,
}

class Obstacle {
  final String id;
  Offset position;
  final ObstacleType type;

  // Size parameters
  final double radius; // Used for circular bumper and vortex
  final Size size;     // Used for rectangular peg

  final Color color;

  // Interactive variables
  double activeTimer = 0.0; // Flash effect when hit or active
  Offset? targetPortal;     // Position for teleporter pair

  Obstacle({
    required this.id,
    required this.position,
    required this.type,
    this.radius = 35.0,
    this.size = const Size(80, 25),
    required this.color,
    this.targetPortal,
  });

  void triggerActivity() {
    activeTimer = 1.0;
  }

  void update(double dt) {
    if (activeTimer > 0) {
      activeTimer -= dt * 4.0;
      if (activeTimer < 0) activeTimer = 0;
    }
  }
}
