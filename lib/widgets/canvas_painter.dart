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

  // Static paint object cache to avoid allocations in paint loop
  static final Paint _gridPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.0;
  static final Paint _centerGlow = Paint();
  static final Paint _linePaint = Paint()..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
  static final Paint _lineGlowPaint = Paint()..strokeCap = StrokeCap.round..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)..style = PaintingStyle.stroke;
  static final Paint _bumperGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
  static final Paint _bumperFill = Paint()..style = PaintingStyle.fill;
  static final Paint _bumperBorder = Paint()..strokeWidth = 3.0..style = PaintingStyle.stroke;
  static final Paint _crossPaint = Paint()..strokeWidth = 1.5;
  static final Paint _pegGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
  static final Paint _pegFill = Paint()..style = PaintingStyle.fill;
  static final Paint _pegStroke = Paint()..strokeWidth = 2.0..style = PaintingStyle.stroke;
  static final Paint _vortexGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
  static final Paint _vortexFill = Paint()..style = PaintingStyle.fill;
  static final Paint _vortexCore = Paint()..style = PaintingStyle.fill;
  static final Paint _teleGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
  static final Paint _teleRing = Paint()..strokeWidth = 3.0..style = PaintingStyle.stroke;
  static final Paint _teleCore = Paint()..style = PaintingStyle.fill;
  static final Paint _dragLinePaint = Paint()..strokeWidth = 3.0..style = PaintingStyle.stroke;
  static final Paint _dragPointPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _dragOuterPaint = Paint()..strokeWidth = 2.0..style = PaintingStyle.stroke;
  static final Paint _trailPaint = Paint()..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
  static final Paint _ballGlow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0);
  static final Paint _ballFill = Paint()..style = PaintingStyle.fill;
  static final Paint _ballBorder = Paint()..strokeWidth = 2.0..style = PaintingStyle.stroke;
  static final Paint _bubbleFill = Paint()..style = PaintingStyle.fill;
  static final Paint _bubbleSheen = Paint()..style = PaintingStyle.fill;
  static final Paint _bubbleStroke = Paint()..strokeWidth = 1.5..style = PaintingStyle.stroke;
  static final Paint _fireFill = Paint()..style = PaintingStyle.fill;
  static final Paint _fireCore = Paint()..style = PaintingStyle.fill;
  static final Paint _discoFill = Paint()..style = PaintingStyle.fill;
  static final Paint _discoGrid = Paint()..strokeWidth = 1.0..style = PaintingStyle.stroke;
  static final Paint _classicFill = Paint()..style = PaintingStyle.fill;
  static final Paint _classicStroke = Paint()..strokeWidth = 1.5..style = PaintingStyle.stroke;

  CustomCanvasPainter({
    required this.balls,
    required this.obstacles,
    required this.lineObstacles,
    this.dragStart,
    this.dragEnd,
    required this.themeColor,
    required this.showGrid,
    required Listenable repaint,
  }) : super(repaint: repaint);

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
    _gridPaint.color = themeColor.withAlpha((0.06 * 255).round());

    const double spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), _gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }

    // Subtly glow center or corners
    _centerGlow.shader = RadialGradient(
      colors: [
        themeColor.withAlpha((0.08 * 255).round()),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2),
        radius: min(size.width, size.height) * 0.7));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _centerGlow);
  }

  void _drawLines(Canvas canvas) {
    for (int i = 0; i < lineObstacles.length; i++) {
      final line = lineObstacles[i];
      _linePaint.color = line.color;
      _linePaint.strokeWidth = line.thickness;

      _lineGlowPaint.color = line.color.withAlpha((0.4 * 255).round());
      _lineGlowPaint.strokeWidth = line.thickness + 6.0;

      canvas.drawLine(line.start, line.end, _lineGlowPaint);
      canvas.drawLine(line.start, line.end, _linePaint);
    }
  }

  void _drawObstacles(Canvas canvas) {
    for (int i = 0; i < obstacles.length; i++) {
      final obs = obstacles[i];
      final double bonusScale = 1.0 + (obs.activeTimer * 0.25);

      switch (obs.type) {
        case ObstacleType.circularBumper:
          final double baseRadius = obs.radius * bonusScale;
          _bumperGlow.color = obs.color.withAlpha((0.35 * 255).round());
          canvas.drawCircle(obs.position, baseRadius + 4, _bumperGlow);

          _bumperFill.shader = RadialGradient(
            colors: [
              obs.color.withAlpha((0.9 * 255).round()),
              obs.color.withAlpha((0.2 * 255).round()),
            ],
          ).createShader(Rect.fromCircle(center: obs.position, radius: baseRadius));
          canvas.drawCircle(obs.position, baseRadius, _bumperFill);

          _bumperBorder.color = Colors.white.withAlpha((0.9 * 255).round());
          canvas.drawCircle(obs.position, baseRadius, _bumperBorder);

          _crossPaint.color = Colors.white.withAlpha((0.5 * 255).round());
          canvas.drawLine(
            obs.position - Offset(baseRadius * 0.4, 0),
            obs.position + Offset(baseRadius * 0.4, 0),
            _crossPaint,
          );
          canvas.drawLine(
            obs.position - Offset(0, baseRadius * 0.4),
            obs.position + Offset(0, baseRadius * 0.4),
            _crossPaint,
          );
          break;

        case ObstacleType.rectangularPeg:
          final double w = obs.size.width * bonusScale;
          final double h = obs.size.height * bonusScale;
          final Rect rect = Rect.fromCenter(center: obs.position, width: w, height: h);
          final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

          _pegGlow.color = obs.color.withAlpha((0.4 * 255).round());
          canvas.drawRRect(rrect.inflate(3), _pegGlow);

          _pegFill.shader = LinearGradient(
            colors: [obs.color, obs.color.withAlpha((0.4 * 255).round())],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect);
          canvas.drawRRect(rrect, _pegFill);

          _pegStroke.color = Colors.white.withAlpha((0.8 * 255).round());
          canvas.drawRRect(rrect, _pegStroke);
          break;

        case ObstacleType.vortex:
          final double r = obs.radius * bonusScale;
          final double spin = DateTime.now().millisecondsSinceEpoch / 400.0;

          _vortexGlow.color = obs.color.withAlpha((0.3 * 255).round());
          canvas.drawCircle(obs.position, r + 10, _vortexGlow);

          for (int idx = 0; idx < 4; idx++) {
            final double angle = spin + (idx * pi / 2);
            _vortexFill.shader = SweepGradient(
              colors: [obs.color, Colors.transparent],
              transform: GradientRotation(angle),
            ).createShader(Rect.fromCircle(center: obs.position, radius: r));
            canvas.drawCircle(obs.position, r, _vortexFill);
          }

          _vortexCore.color = Colors.black.withAlpha((0.8 * 255).round());
          canvas.drawCircle(obs.position, r * 0.3, _vortexCore);
          break;

        case ObstacleType.teleporter:
          final double r = obs.radius;
          final double pulse = 1.0 + 0.1 * sin(DateTime.now().millisecondsSinceEpoch / 150.0);

          _teleGlow.color = obs.color.withAlpha((0.5 * 255).round());
          canvas.drawCircle(obs.position, r * pulse + 2, _teleGlow);

          _teleRing.color = obs.color;
          canvas.drawCircle(obs.position, r, _teleRing);
          canvas.drawCircle(obs.position, r * 0.7 * pulse, _teleRing);

          _teleCore.color = Colors.black.withAlpha((0.4 * 255).round());
          canvas.drawCircle(obs.position, r * 0.4, _teleCore);
          break;
      }
    }
  }

  void _drawDragGuide(Canvas canvas) {
    if (dragStart != null && dragEnd != null) {
      final double distance = (dragStart! - dragEnd!).distance;
      if (distance < 5.0) return;

      _dragLinePaint.color = Colors.white.withAlpha((0.7 * 255).round());

      final Offset direction = (dragStart! - dragEnd!);

      const double dashLength = 10.0;
      const double spaceLength = 8.0;
      final Offset norm = direction / (direction.distance == 0 ? 1 : direction.distance);
      double currentDist = 0.0;
      final double totalDist = direction.distance * 1.5;

      while (currentDist < totalDist) {
        final Offset p1 = dragStart! + norm * currentDist;
        final Offset p2 = dragStart! + norm * min(currentDist + dashLength, totalDist);
        canvas.drawLine(p1, p2, _dragLinePaint);
        currentDist += dashLength + spaceLength;
      }

      _dragPointPaint.color = Colors.white;
      canvas.drawCircle(dragStart!, 6, _dragPointPaint);

      _dragOuterPaint.color = Colors.pinkAccent.withAlpha((0.8 * 255).round());
      canvas.drawCircle(dragStart!, 12 + sin(DateTime.now().millisecondsSinceEpoch / 100) * 4, _dragOuterPaint);
    }
  }

  void _drawBalls(Canvas canvas) {
    for (int i = 0; i < balls.length; i++) {
      final ball = balls[i];
      _drawBallTrail(canvas, ball);

      canvas.save();
      canvas.translate(ball.position.dx, ball.position.dy);

      double speed = ball.velocity.distance;
      if (speed > 5.0) {
        final double angle = ball.velocity.direction;
        canvas.rotate(angle);
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
      final double progress = i / ball.trail.length;

      final double thickness = ball.radius * 0.8 * progress;

      _trailPaint.color = ball.color.withAlpha((progress * 0.45 * 255).round());
      _trailPaint.strokeWidth = thickness;

      canvas.drawLine(p1, p2, _trailPaint);
    }
  }

  void _drawBallSkin(Canvas canvas, Ball ball) {
    final Rect ballRect = Rect.fromCircle(center: Offset.zero, radius: ball.radius);

    switch (ball.skin) {
      case BallSkin.neonGlow:
        _ballGlow.color = ball.color.withAlpha((0.4 * 255).round());
        canvas.drawCircle(Offset.zero, ball.radius + 6, _ballGlow);

        _ballFill.shader = RadialGradient(
          colors: [Colors.white, ball.color, ball.color.withAlpha((0.7 * 255).round())],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(ballRect);
        canvas.drawCircle(Offset.zero, ball.radius, _ballFill);

        _ballBorder.color = Colors.white;
        canvas.drawCircle(Offset.zero, ball.radius, _ballBorder);
        break;

      case BallSkin.bubble:
        _bubbleFill.shader = RadialGradient(
          colors: [
            Colors.white.withAlpha(0),
            ball.color.withAlpha((0.2 * 255).round()),
            ball.color.withAlpha((0.7 * 255).round()),
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(ballRect);
        canvas.drawCircle(Offset.zero, ball.radius, _bubbleFill);

        _bubbleSheen.color = Colors.white.withAlpha((0.75 * 255).round());
        canvas.drawOval(
          Rect.fromLTWH(-ball.radius * 0.6, -ball.radius * 0.6, ball.radius * 0.5, ball.radius * 0.3),
          _bubbleSheen,
        );

        _bubbleStroke.color = Colors.white.withAlpha((0.9 * 255).round());
        canvas.drawCircle(Offset.zero, ball.radius, _bubbleStroke);
        break;

      case BallSkin.fireball:
        _fireFill.shader = RadialGradient(
          colors: [Colors.yellowAccent, Colors.orange, Colors.red, Colors.transparent],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ).createShader(ballRect);
        canvas.drawCircle(Offset.zero, ball.radius * 1.3, _fireFill);

        _fireCore.color = Colors.white;
        canvas.drawCircle(Offset.zero, ball.radius * 0.5, _fireCore);
        break;

      case BallSkin.disco:
        final dynamicColor = HSVColor.fromAHSV(
          1.0,
          (DateTime.now().millisecondsSinceEpoch / 5) % 360,
          0.85,
          0.95,
        ).toColor();

        _discoFill.shader = RadialGradient(
          colors: [Colors.white, dynamicColor, dynamicColor.withAlpha((0.8 * 255).round())],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(ballRect);
        canvas.drawCircle(Offset.zero, ball.radius, _discoFill);

        _discoGrid.color = Colors.black.withAlpha((0.25 * 255).round());
        canvas.drawLine(Offset(-ball.radius, 0), Offset(ball.radius, 0), _discoGrid);
        canvas.drawLine(Offset(0, -ball.radius), Offset(0, ball.radius), _discoGrid);
        canvas.drawLine(Offset(-ball.radius * 0.7, -ball.radius * 0.7), Offset(ball.radius * 0.7, ball.radius * 0.7), _discoGrid);
        canvas.drawLine(Offset(-ball.radius * 0.7, ball.radius * 0.7), Offset(ball.radius * 0.7, -ball.radius * 0.7), _discoGrid);
        break;

      case BallSkin.classic:
        _classicFill.shader = RadialGradient(
          colors: [Colors.white, ball.color, ball.color.withAlpha((0.9 * 255).round())],
          stops: const [0.0, 0.4, 1.0],
          center: const Alignment(-0.3, -0.3),
        ).createShader(ballRect);
        canvas.drawCircle(Offset.zero, ball.radius, _classicFill);

        _classicStroke.color = Colors.black.withAlpha((0.15 * 255).round());
        canvas.drawCircle(Offset.zero, ball.radius, _classicStroke);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant CustomCanvasPainter oldDelegate) {
    return true; // We always repaint when the repaint listenable triggers
  }
}
