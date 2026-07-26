import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bouncing_ball/models/ball.dart';
import 'package:bouncing_ball/models/obstacle.dart';
import 'package:bouncing_ball/models/particle.dart';
import 'package:bouncing_ball/widgets/canvas_painter.dart';
import 'package:bouncing_ball/widgets/grid_painter.dart';

void main() {
  group('Ball Model Unit Tests', () {
    test('Initialization values are correct', () {
      final ball = Ball(
        position: const Offset(10, 20),
        velocity: const Offset(5, -5),
        radius: 15.0,
        color: Colors.red,
        skin: BallSkin.fireball,
      );

      expect(ball.position.dx, 10.0);
      expect(ball.position.dy, 20.0);
      expect(ball.velocity.dx, 5.0);
      expect(ball.velocity.dy, -5.0);
      expect(ball.radius, 15.0);
      expect(ball.color, Colors.red);
      expect(ball.skin, BallSkin.fireball);
      expect(ball.trail, isEmpty);
    });

    test('updateTrail tracks and limits points correctly', () {
      final ball = Ball(
        position: const Offset(10, 10),
        velocity: const Offset(1, 1),
        radius: 10,
        color: Colors.cyan,
      );

      for (int i = 0; i < 20; i++) {
        ball.position = Offset(i * 1.0, i * 1.0);
        ball.updateTrail();
      }

      expect(ball.trail.length, 15); // Max trail length
      expect(ball.trail.last, const Offset(19.0, 19.0));
    });

    test('applySquash sets correct deformation scale', () {
      final ball = Ball(
        position: const Offset(10, 10),
        velocity: const Offset(1, 1),
        radius: 10,
        color: Colors.cyan,
      );

      ball.applySquash(0.5, 1.5);
      expect(ball.squashX, 0.5);
      expect(ball.squashY, 1.5);
      expect(ball.squashTimer, 1.0);
    });

    test('decaySquash recovers scale over time', () {
      final ball = Ball(
        position: const Offset(10, 10),
        velocity: const Offset(1, 1),
        radius: 10,
        color: Colors.cyan,
      );

      ball.applySquash(0.5, 1.5);
      ball.decaySquash(0.1);

      expect(ball.squashTimer, lessThan(1.0));
      expect(ball.squashX, greaterThan(0.5));
      expect(ball.squashY, lessThan(1.5));
    });
  });

  group('Obstacle Model Unit Tests', () {
    test('Initialization values are correct', () {
      final obstacle = Obstacle(
        id: 'portal_test',
        position: const Offset(100, 100),
        type: ObstacleType.teleporter,
        radius: 25,
        color: Colors.blue,
        targetPortal: const Offset(200, 200),
      );

      expect(obstacle.id, 'portal_test');
      expect(obstacle.position, const Offset(100, 100));
      expect(obstacle.type, ObstacleType.teleporter);
      expect(obstacle.radius, 25);
      expect(obstacle.color, Colors.blue);
      expect(obstacle.targetPortal, const Offset(200, 200));
      expect(obstacle.activeTimer, 0.0);
    });

    test('Triggering activity flashes activeTimer', () {
      final obstacle = Obstacle(
        id: 'bumper',
        position: const Offset(50, 50),
        type: ObstacleType.circularBumper,
        color: Colors.green,
      );

      obstacle.triggerActivity();
      expect(obstacle.activeTimer, 1.0);

      obstacle.update(0.1);
      expect(obstacle.activeTimer, lessThan(1.0));
    });
  });

  group('Particle Model Unit Tests', () {
    test('Particle updates and dies properly', () {
      final particle = Particle(
        position: const Offset(0, 0),
        velocity: const Offset(10, 10),
        color: Colors.yellow,
        size: 5.0,
        maxLifespan: 0.5,
      );

      expect(particle.isDead, isFalse);

      particle.update(0.3);
      expect(particle.lifespan, closeTo(0.2, 0.001));
      expect(particle.position.dx, greaterThan(0));

      particle.update(0.3);
      expect(particle.isDead, isTrue);
    });
  });

  group('Painters Unit Tests', () {
    test('GridPainter shouldRepaint test', () {
      final painter1 = GridPainter(themeColor: Colors.red);
      final painter2 = GridPainter(themeColor: Colors.red);
      final painter3 = GridPainter(themeColor: Colors.blue);

      expect(painter1.shouldRepaint(painter2), isFalse);
      expect(painter1.shouldRepaint(painter3), isTrue);
    });

    test('CustomCanvasPainter shouldRepaint is false', () {
      final notifier = ValueNotifier<int>(0);
      final painter = CustomCanvasPainter(
        repaint: notifier,
        balls: [],
        obstacles: [],
        lineObstacles: [],
        themeColor: Colors.red,
      );
      expect(painter.shouldRepaint(painter), isFalse);
      notifier.dispose();
    });
  });
}
