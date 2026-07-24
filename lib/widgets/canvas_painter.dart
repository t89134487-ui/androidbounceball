import 'dart:math';
import 'package:flutter/material.dart';
import '../models/ball.dart';
import '../models/obstacle.dart';
import '../models/line_obstacle.dart';

class CustomCanvasPainter extends CustomPainter {
  final List<Ball> balls;
  final List<Obstacle> obstacles;
  final List<LineObstacle> lineObstacles;
  final Offset? dragStart;
  final Offset? dragEnd;
  final Color themeColor;
  final bool showGrid;

  CustomCanvasPainter({
    required this.balls,
    required this.obstacles,
    required this.lineObstacles,
    this.dragStart,
    this.dragEnd,
    required this.themeColor,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw futuristic space grid background
    if (showGrid) {
      _drawBackgroundGrid(canvas, size);
    }

    // 2. Draw user-drawn obstacle lines
    _drawLines(canvas);

    // 3. Draw standard bumpers/obstacles (Vortex, Teleporter, Peg, Bumper)
    _drawObstacles(canvas);

    // 4. Draw drag-to-shoot line or drag-to-draw line
    _drawDragGuide(canvas);

    // 5. Draw balls and trails
    _drawBalls(canvas);
  }

  void _drawBackgroundGrid(Canvas canvas, Size size) {
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
          radius: min(size.width, size.height) * 0.7));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), centerGlow);
  }

  void _drawLines(Canvas canvas) {
    for (final line in lineObstacles) {
      final linePaint = Paint()
        ..color = line.color
        ..strokeWidth = line.thickness
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      // Outer glow of lines
      final glowPaint = Paint()
        ..color = line.color.withAlpha((0.4 * 255).round())
        ..strokeWidth = line.thickness + 6.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..style = PaintingStyle.stroke;

      canvas.drawLine(line.start, line.end, glowPaint);
      canvas.drawLine(line.start, line.end, linePaint);
    }
  }

  void _drawObstacles(Canvas canvas) {
    for (final obs in obstacles) {
      final double bonusScale = 1.0 + (obs.activeTimer * 0.25);

      switch (obs.type) {
        case ObstacleType.circularBumper:
          // Draw Neon Ring Bumper
          final double baseRadius = obs.radius * bonusScale;
          final outerGlow = Paint()
            ..color = obs.color.withAlpha((0.35 * 255).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
          canvas.drawCircle(obs.position, baseRadius + 4, outerGlow);

          final fillPaint = Paint()
            ..shader = RadialGradient(
              colors: [
                obs.color.withAlpha((0.9 * 255).round()),
                obs.color.withAlpha((0.2 * 255).round()),
              ],
            ).createShader(Rect.fromCircle(center: obs.position, radius: baseRadius))
            ..style = PaintingStyle.fill;
          canvas.drawCircle(obs.position, baseRadius, fillPaint);

          final borderPaint = Paint()
            ..color = Colors.white.withAlpha((0.9 * 255).round())
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(obs.position, baseRadius, borderPaint);

          // Draw inner target star or crosshair
          final crossPaint = Paint()
            ..color = Colors.white.withAlpha((0.5 * 255).round())
            ..strokeWidth = 1.5;
          canvas.drawLine(
            obs.position - Offset(baseRadius * 0.4, 0),
            obs.position + Offset(baseRadius * 0.4, 0),
            crossPaint,
          );
          canvas.drawLine(
            obs.position - Offset(0, baseRadius * 0.4),
            obs.position + Offset(0, baseRadius * 0.4),
            crossPaint,
          );
          break;

        case ObstacleType.rectangularPeg:
          final double w = obs.size.width * bonusScale;
          final double h = obs.size.height * bonusScale;
          final Rect rect = Rect.fromCenter(center: obs.position, width: w, height: h);
          final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

          final glowPaint = Paint()
            ..color = obs.color.withAlpha((0.4 * 255).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
          canvas.drawRRect(rrect.inflate(3), glowPaint);

          final fillPaint = Paint()
            ..shader = LinearGradient(
              colors: [obs.color, obs.color.withAlpha((0.4 * 255).round())],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect)
            ..style = PaintingStyle.fill;
          canvas.drawRRect(rrect, fillPaint);

          final strokePaint = Paint()
            ..color = Colors.white.withAlpha((0.8 * 255).round())
            ..strokeWidth = 2.0
            ..style = PaintingStyle.stroke;
          canvas.drawRRect(rrect, strokePaint);
          break;

        case ObstacleType.vortex:
          // Spin/whirlpool effect using activeTimer or a sine wave
          final double r = obs.radius * bonusScale;
          final double spin = DateTime.now().millisecondsSinceEpoch / 400.0;

          final glowPaint = Paint()
            ..color = obs.color.withAlpha((0.3 * 255).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
          canvas.drawCircle(obs.position, r + 10, glowPaint);

          // Swirling lines
          for (int i = 0; i < 4; i++) {
            final double angle = spin + (i * pi / 2);
            final swirlPaint = Paint()
              ..shader = SweepGradient(
                colors: [obs.color, Colors.transparent],
                transform: GradientRotation(angle),
              ).createShader(Rect.fromCircle(center: obs.position, radius: r))
              ..style = PaintingStyle.fill;
            canvas.drawCircle(obs.position, r, swirlPaint);
          }

          // Dark core
          final corePaint = Paint()
            ..color = Colors.black.withAlpha((0.8 * 255).round())
            ..style = PaintingStyle.fill;
          canvas.drawCircle(obs.position, r * 0.3, corePaint);
          break;

        case ObstacleType.teleporter:
          // Draw energetic neon portal circles with concentric pulsing rings
          final double r = obs.radius;
          final double pulse = 1.0 + 0.1 * sin(DateTime.now().millisecondsSinceEpoch / 150.0);

          // Outer magical glow
          final glowPaint = Paint()
            ..color = obs.color.withAlpha((0.5 * 255).round())
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
          canvas.drawCircle(obs.position, r * pulse + 2, glowPaint);

          // Concentric portal rings
          final ringPaint = Paint()
            ..color = obs.color
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(obs.position, r, ringPaint);
          canvas.drawCircle(obs.position, r * 0.7 * pulse, ringPaint);

          final corePaint = Paint()
            ..color = Colors.black.withAlpha((0.4 * 255).round())
            ..style = PaintingStyle.fill;
          canvas.drawCircle(obs.position, r * 0.4, corePaint);
          break;
      }
    }
  }

  void _drawDragGuide(Canvas canvas) {
    if (dragStart != null && dragEnd != null) {
      final double distance = (dragStart! - dragEnd!).distance;
      if (distance < 5.0) return;

      // Draw dashed trajectory line
      final linePaint = Paint()
        ..color = Colors.white.withAlpha((0.7 * 255).round())
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final Offset direction = (dragStart! - dragEnd!);

      // Simple dashed line implementation
      const double dashLength = 10.0;
      const double spaceLength = 8.0;
      final Offset norm = direction / (direction.distance == 0 ? 1 : direction.distance);
      double currentDist = 0.0;
      final double totalDist = direction.distance * 1.5; // Extend trajectory forward

      while (currentDist < totalDist) {
        final Offset p1 = dragStart! + norm * currentDist;
        final Offset p2 = dragStart! + norm * min(currentDist + dashLength, totalDist);
        canvas.drawLine(p1, p2, linePaint);
        currentDist += dashLength + spaceLength;
      }

      // Draw target indicator at the release point
      final circlePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dragStart!, 6, circlePaint);

      final outerAimPaint = Paint()
        ..color = Colors.pinkAccent.withAlpha((0.8 * 255).round())
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(dragStart!, 12 + sin(DateTime.now().millisecondsSinceEpoch / 100) * 4, outerAimPaint);
    }
  }

  void _drawBalls(Canvas canvas) {
    for (final ball in balls) {
      // 1. Draw glowing neon trails
      _drawBallTrail(canvas, ball);

      // 2. Determine skin decoration and draw ball
      canvas.save();
      // Move to ball's position
      canvas.translate(ball.position.dx, ball.position.dy);

      // Apply squash and stretch transformation relative to movement angle
      double speed = ball.velocity.distance;
      if (speed > 5.0) {
        final double angle = ball.velocity.direction;
        canvas.rotate(angle);
        // Squash along motion direction, stretch perpendicular
        canvas.scale(ball.squashX, ball.squashY);
      } else {
        canvas.scale(ball.squashX, ball.squashY);
      }

      _drawBallSkin(canvas, ball);

      canvas.restore();
    }
  }

  void _drawBallTrail(Canvas canvas, Ball ball) {
    if (ball.trail.length < 2) return;

    for (int i = 0; i < ball.trail.length - 1; i++) {
      final Offset p1 = ball.trail[i];
      final Offset p2 = ball.trail[i + 1];
      final double progress = i / ball.trail.length; // 0.0 to 1.0

      // Thicker trail near the ball, thinner at the tail
      final double thickness = ball.radius * 0.8 * progress;

      final trailPaint = Paint()
        ..color = ball.color.withAlpha((progress * 0.45 * 255).round())
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(p1, p2, trailPaint);
    }
  }

  void _drawBallSkin(Canvas canvas, Ball ball) {
    final Rect ballRect = Rect.fromCircle(center: Offset.zero, radius: ball.radius);

    switch (ball.skin) {
      case BallSkin.neonGlow:
        // Thick glowing neon ball
        final glowPaint = Paint()
          ..color = ball.color.withAlpha((0.4 * 255).round())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
        canvas.drawCircle(Offset.zero, ball.radius + 6, glowPaint);

        final fillPaint = Paint()
          ..shader = RadialGradient(
            colors: [Colors.white, ball.color, ball.color.withAlpha((0.7 * 255).round())],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(ballRect)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, ball.radius, fillPaint);

        // Highlight ring
        final borderPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset.zero, ball.radius, borderPaint);
        break;

      case BallSkin.bubble:
        // Semi-transparent soapy bubble with colorful glare
        final fillPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withAlpha(0),
              ball.color.withAlpha((0.2 * 255).round()),
              ball.color.withAlpha((0.7 * 255).round()),
            ],
            stops: const [0.0, 0.7, 1.0],
          ).createShader(ballRect)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, ball.radius, fillPaint);

        // Highlight sheen (glare)
        final sheenPaint = Paint()
          ..color = Colors.white.withAlpha((0.75 * 255).round())
          ..style = PaintingStyle.fill;
        canvas.drawOval(
          Rect.fromLTWH(-ball.radius * 0.6, -ball.radius * 0.6, ball.radius * 0.5, ball.radius * 0.3),
          sheenPaint,
        );

        final strokePaint = Paint()
          ..color = Colors.white.withAlpha((0.9 * 255).round())
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset.zero, ball.radius, strokePaint);
        break;

      case BallSkin.fireball:
        // Fiery gradients radiating outwards
        final firePaint = Paint()
          ..shader = RadialGradient(
            colors: [Colors.yellowAccent, Colors.orange, Colors.red, Colors.transparent],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ).createShader(ballRect)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, ball.radius * 1.3, firePaint);

        final corePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, ball.radius * 0.5, corePaint);
        break;

      case BallSkin.disco:
        // Shimmering disco ball panels or rotating color hue
        final dynamicColor = HSVColor.fromAHSV(
          1.0,
          (DateTime.now().millisecondsSinceEpoch / 5) % 360,
          0.85,
          0.95,
        ).toColor();

        final fillPaint = Paint()
          ..shader = RadialGradient(
            colors: [Colors.white, dynamicColor, dynamicColor.withAlpha((0.8 * 255).round())],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(ballRect)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, ball.radius, fillPaint);

        // Disco grid lines
        final gridPaint = Paint()
          ..color = Colors.black.withAlpha((0.25 * 255).round())
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(-ball.radius, 0), Offset(ball.radius, 0), gridPaint);
        canvas.drawLine(Offset(0, -ball.radius), Offset(0, ball.radius), gridPaint);
        canvas.drawLine(Offset(-ball.radius * 0.7, -ball.radius * 0.7), Offset(ball.radius * 0.7, ball.radius * 0.7), gridPaint);
        canvas.drawLine(Offset(-ball.radius * 0.7, ball.radius * 0.7), Offset(ball.radius * 0.7, -ball.radius * 0.7), gridPaint);
        break;

      case BallSkin.classic:
        // Standard clean spherical looking bouncy ball
        final fillPaint = Paint()
          ..shader = RadialGradient(
            colors: [Colors.white, ball.color, ball.color.withAlpha((0.9 * 255).round())],
            stops: const [0.0, 0.4, 1.0],
            center: const Alignment(-0.3, -0.3),
          ).createShader(ballRect)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, ball.radius, fillPaint);

        final strokePaint = Paint()
          ..color = Colors.black.withAlpha((0.15 * 255).round())
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset.zero, ball.radius, strokePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomCanvasPainter oldDelegate) {
    return true; // Continuously animate
  }
}
