import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../models/ball.dart';
import '../models/obstacle.dart';
import '../models/line_obstacle.dart';
import '../models/particle.dart';
import 'canvas_painter.dart';
import 'grid_painter.dart';
import 'particle_painter.dart';

class PhysicsPlayground extends StatefulWidget {
  const PhysicsPlayground({super.key});

  @override
  State<PhysicsPlayground> createState() => _PhysicsPlaygroundState();
}

class _PhysicsPlaygroundState extends State<PhysicsPlayground> with SingleTickerProviderStateMixin {
  // Primary engine loop using high performance Scheduler Ticker
  late final Ticker _ticker;

  // Change notification to repaint canvas dynamically without rebuilding whole widget tree
  final ValueNotifier<int> _canvasRepaintNotifier = ValueNotifier<int>(0);

  // Keep track of total elapsed time for physics step safety
  Duration _lastElapsed = Duration.zero;

  // Physical State Variables
  final List<Ball> _balls = [];
  final List<Obstacle> _obstacles = [];
  final List<LineObstacle> _lineObstacles = [];
  final List<Particle> _particles = [];

  // Configuration values (interactive through UI)
  double _gravityY = 350.0;
  final double _gravityX = 0.0;
  double _windPower = 0.0;
  double _restitution = 0.85; // Bounce factor (0.0 to 1.1)
  final double _particleExplosionPower = 200.0;
  BallSkin _selectedSkin = BallSkin.neonGlow;
  Color _selectedBallColor = Colors.cyanAccent;
  final Color _currentThemeColor = Colors.deepPurpleAccent;

  // Toggle flags
  bool _enableVortex = true;
  bool _enableTeleporters = true;
  bool _enableBumpers = true;
  bool _showGrid = true;
  bool _ballToBallCollision = true;

  // Drawing state
  String _activeTool = 'shoot'; // 'shoot', 'draw', 'erase'
  Offset? _dragStart;
  Offset? _dragEnd;

  // Preset colors for customization
  final List<Color> _availableColors = [
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.greenAccent,
    Colors.amberAccent,
    Colors.purpleAccent,
    Colors.redAccent,
    Colors.white,
  ];

  @override
  void initState() {
    super.initState();

    // Prepare default setup
    _resetDemoEnvironmentInternal();

    // Initialize and start frame-rate-independent Ticker
    _ticker = createTicker(_onTick);
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _canvasRepaintNotifier.dispose();
    super.dispose();
  }

  void _resetDemoEnvironment() {
    setState(() {
      _resetDemoEnvironmentInternal();
    });
  }

  void _resetDemoEnvironmentInternal() {
    _balls.clear();
    _obstacles.clear();
    _lineObstacles.clear();
    _particles.clear();

    // Add initial bouncy balls (including orange balls as requested)
    _balls.addAll([
      Ball(
        position: const Offset(100, 150),
        velocity: const Offset(120, -80),
        radius: 18.0,
        color: Colors.cyanAccent,
        skin: BallSkin.neonGlow,
      ),
      Ball(
        position: const Offset(280, 200),
        velocity: const Offset(-150, 120),
        radius: 22.0,
        color: Colors.pinkAccent,
        skin: BallSkin.bubble,
      ),
      Ball(
        position: const Offset(180, 80),
        velocity: const Offset(90, 180),
        radius: 16.0,
        color: Colors.greenAccent,
        skin: BallSkin.disco,
      ),
      Ball(
        position: const Offset(150, 220),
        velocity: const Offset(140, -110),
        radius: 20.0,
        color: Colors.orangeAccent,
        skin: BallSkin.fireball,
      ),
      Ball(
        position: const Offset(220, 140),
        velocity: const Offset(-110, 140),
        radius: 17.0,
        color: Colors.orange,
        skin: BallSkin.classic,
      ),
    ]);

    _recreateObstaclesInternal();
    _canvasRepaintNotifier.value++;
  }

  void _recreateObstaclesInternal() {
    _obstacles.clear();

    // Standard high-scoring, high-bouncing circular bumpers
    if (_enableBumpers) {
      _obstacles.addAll([
        Obstacle(
          id: 'bumper_1',
          position: const Offset(120, 320),
          type: ObstacleType.circularBumper,
          radius: 30.0,
          color: Colors.pinkAccent,
        ),
        Obstacle(
          id: 'bumper_2',
          position: const Offset(280, 320),
          type: ObstacleType.circularBumper,
          radius: 30.0,
          color: Colors.cyanAccent,
        ),
        Obstacle(
          id: 'peg_1',
          position: const Offset(200, 480),
          type: ObstacleType.rectangularPeg,
          size: const Size(120, 24),
          color: Colors.amberAccent,
        ),
      ]);
    }

    // Portal pair (Inward / Outward)
    if (_enableTeleporters) {
      _obstacles.addAll([
        Obstacle(
          id: 'teleport_in',
          position: const Offset(60, 580),
          type: ObstacleType.teleporter,
          radius: 20.0,
          color: Colors.blueAccent,
          targetPortal: const Offset(340, 120),
        ),
        Obstacle(
          id: 'teleport_out',
          position: const Offset(340, 120),
          type: ObstacleType.teleporter,
          radius: 20.0,
          color: Colors.purpleAccent,
          targetPortal: const Offset(60, 580),
        ),
      ]);
    }

    // Center Gravitational Vortex
    if (_enableVortex) {
      _obstacles.add(
        Obstacle(
          id: 'vortex_center',
          position: const Offset(200, 220),
          type: ObstacleType.vortex,
          radius: 25.0,
          color: Colors.indigoAccent,
        ),
      );
    }
  }

  void _onTick(Duration elapsed) {
    if (_lastElapsed == Duration.zero) {
      _lastElapsed = elapsed;
      return;
    }

    // Compute delta time in seconds, clamped to safe ranges (e.g. max 0.1s to avoid physics explosions)
    double dt = (elapsed.inMicroseconds - _lastElapsed.inMicroseconds) / 1000000.0;
    _lastElapsed = elapsed;

    if (dt > 0.1) dt = 0.1;
    if (dt <= 0) return;

    // 1. Particle life cycles
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt);
      if (_particles[i].isDead) {
        _particles.removeAt(i);
      }
    }

    // 2. Obstacle pulsing updates
    for (final obs in _obstacles) {
      obs.update(dt);
    }

    // 3. Physics Updates with continuous sub-stepping
    _runPhysicsSubSteps(dt);

    // Notify listeners to trigger redraw on painters only, without reconstructing widget tree!
    _canvasRepaintNotifier.value++;
  }

  void _runPhysicsSubSteps(double dt) {
    const int subSteps = 3;
    final double sdt = dt / subSteps;

    for (int step = 0; step < subSteps; step++) {
      _applyForcesAndMovement(sdt);
      _resolveCollisions(sdt);
    }
  }

  void _applyForcesAndMovement(double sdt) {
    for (final ball in _balls) {
      double totalForceX = _gravityX + _windPower;
      double totalForceY = _gravityY;

      // Vortex Gravitational Attraction
      if (_enableVortex) {
        for (final obs in _obstacles) {
          if (obs.type == ObstacleType.vortex) {
            final Offset dir = obs.position - ball.position;
            final double dist = dir.distance;
            if (dist < 280.0 && dist > 5.0) {
              final double pullStrength = 180000.0 / (dist * dist + 1000.0);
              final Offset attraction = (dir / dist) * pullStrength;
              totalForceX += attraction.dx;
              totalForceY += attraction.dy;
            }
          }
        }
      }

      // Update velocities & locations
      ball.velocity = Offset(
        ball.velocity.dx + totalForceX * sdt,
        ball.velocity.dy + totalForceY * sdt,
      );

      ball.position += ball.velocity * sdt;

      // Update trails
      ball.updateTrail();

      // Decay visual squash state
      ball.decaySquash(sdt);
    }
  }

  void _resolveCollisions(double sdt) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height - 250;

    for (final ball in _balls) {
      const double padding = 2.0;

      // Left Wall
      if (ball.position.dx - ball.radius < padding) {
        ball.position = Offset(ball.radius + padding, ball.position.dy);
        ball.velocity = Offset(-ball.velocity.dx * _restitution, ball.velocity.dy);
        ball.applySquash(0.65, 1.35);
        _spawnImpactParticles(ball.position - Offset(ball.radius, 0), ball.color, 8);
        HapticFeedback.lightImpact();
      }
      // Right Wall
      else if (ball.position.dx + ball.radius > width - padding) {
        ball.position = Offset(width - ball.radius - padding, ball.position.dy);
        ball.velocity = Offset(-ball.velocity.dx * _restitution, ball.velocity.dy);
        ball.applySquash(0.65, 1.35);
        _spawnImpactParticles(ball.position + Offset(ball.radius, 0), ball.color, 8);
        HapticFeedback.lightImpact();
      }

      // Top Wall
      if (ball.position.dy - ball.radius < padding) {
        ball.position = Offset(ball.position.dx, ball.radius + padding);
        ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy * _restitution);
        ball.applySquash(1.35, 0.65);
        _spawnImpactParticles(ball.position - Offset(0, ball.radius), ball.color, 8);
        HapticFeedback.lightImpact();
      }
      // Bottom Wall
      else if (ball.position.dy + ball.radius > height) {
        ball.position = Offset(ball.position.dx, height - ball.radius);
        ball.velocity = Offset(ball.velocity.dx, -ball.velocity.dy * _restitution);
        ball.applySquash(1.35, 0.65);
        _spawnImpactParticles(ball.position + Offset(0, ball.radius), ball.color, 8);
        HapticFeedback.lightImpact();
      }

      // --- COLLISION: Obstacles/Bumpers ---
      for (final obs in _obstacles) {
        if (obs.type == ObstacleType.circularBumper || obs.type == ObstacleType.vortex || obs.type == ObstacleType.teleporter) {
          final double distance = (ball.position - obs.position).distance;
          final double minDistance = ball.radius + obs.radius;

          if (distance < minDistance) {
            final Offset normal = (ball.position - obs.position) / (distance == 0 ? 1 : distance);

            if (obs.type == ObstacleType.teleporter && _enableTeleporters) {
              if (obs.targetPortal != null) {
                _spawnImpactParticles(ball.position, obs.color, 15);
                ball.position = obs.targetPortal!;
                ball.velocity = normal * (ball.velocity.distance + 40.0);
                _spawnImpactParticles(ball.position, obs.color, 15);
                obs.triggerActivity();
                HapticFeedback.mediumImpact();
                break;
              }
            } else if (obs.type == ObstacleType.vortex) {
              ball.velocity = (normal * ball.velocity.distance) + Offset(-normal.dy, normal.dx) * 45;
            } else {
              ball.position = obs.position + normal * minDistance;

              final double dotProduct = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
              ball.velocity = Offset(
                (ball.velocity.dx - 2 * dotProduct * normal.dx) * (_restitution + 0.15),
                (ball.velocity.dy - 2 * dotProduct * normal.dy) * (_restitution + 0.15),
              );

              ball.applySquash(0.55, 1.45);
              obs.triggerActivity();
              _spawnImpactParticles(ball.position, obs.color, 14);
              HapticFeedback.mediumImpact();
            }
          }
        }
        else if (obs.type == ObstacleType.rectangularPeg) {
          final double halfW = obs.size.width / 2;
          final double halfH = obs.size.height / 2;

          final double closestX = max(obs.position.dx - halfW, min(ball.position.dx, obs.position.dx + halfW));
          final double closestY = max(obs.position.dy - halfH, min(ball.position.dy, obs.position.dy + halfH));

          final Offset closestPoint = Offset(closestX, closestY);
          final double distance = (ball.position - closestPoint).distance;

          if (distance < ball.radius) {
            final Offset normalDir = ball.position - closestPoint;
            final Offset normal = normalDir.distance == 0
                ? const Offset(0, -1)
                : normalDir / normalDir.distance;

            ball.position = closestPoint + normal * ball.radius;

            final double dotProduct = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
            ball.velocity = Offset(
              (ball.velocity.dx - 2 * dotProduct * normal.dx) * _restitution,
              (ball.velocity.dy - 2 * dotProduct * normal.dy) * _restitution,
            );

            ball.applySquash(1.4, 0.6);
            obs.triggerActivity();
            _spawnImpactParticles(closestPoint, obs.color, 12);
            HapticFeedback.mediumImpact();
          }
        }
      }

      // --- COLLISION: Custom drawn line obstacles ---
      for (final line in _lineObstacles) {
        if (_checkCircleLineCollision(ball, line)) {
          HapticFeedback.mediumImpact();
        }
      }
    }

    // --- COLLISION: Ball-to-ball elastic collisions ---
    if (_ballToBallCollision && _balls.length > 1) {
      for (int i = 0; i < _balls.length; i++) {
        for (int j = i + 1; j < _balls.length; j++) {
          final b1 = _balls[i];
          final b2 = _balls[j];

          final double distance = (b1.position - b2.position).distance;
          final double minDistance = b1.radius + b2.radius;

          if (distance < minDistance) {
            final Offset normal = (b2.position - b1.position) / (distance == 0 ? 1 : distance);

            final double overlap = minDistance - distance;
            b1.position -= normal * (overlap * 0.5);
            b2.position += normal * (overlap * 0.5);

            final Offset relVel = b2.velocity - b1.velocity;
            final double velAlongNormal = relVel.dx * normal.dx + relVel.dy * normal.dy;

            if (velAlongNormal < 0) {
              final double impulseScalar = -(1.0 + _restitution) * velAlongNormal / 2;
              final Offset impulse = normal * impulseScalar;

              b1.velocity -= impulse;
              b2.velocity += impulse;

              b1.applySquash(0.7, 1.3);
              b2.applySquash(0.7, 1.3);

              _spawnImpactParticles((b1.position + b2.position) * 0.5, b1.color, 10);
              HapticFeedback.lightImpact();
            }
          }
        }
      }
    }
  }

  bool _checkCircleLineCollision(Ball ball, LineObstacle line) {
    final Offset ab = line.end - line.start;
    final Offset ap = ball.position - line.start;

    final double abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (abLenSq == 0) return false;

    double t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
    t = max(0.0, min(1.0, t));

    final Offset closestPoint = line.start + ab * t;
    final double dist = (ball.position - closestPoint).distance;
    final double collisionThresh = ball.radius + (line.thickness / 2);

    if (dist < collisionThresh) {
      final Offset normalDir = ball.position - closestPoint;
      final Offset normal = normalDir.distance == 0
          ? Offset(-ab.dy, ab.dx) / sqrt(abLenSq)
          : normalDir / normalDir.distance;

      ball.position = closestPoint + normal * collisionThresh;

      final double dotProduct = ball.velocity.dx * normal.dx + ball.velocity.dy * normal.dy;
      ball.velocity = Offset(
        (ball.velocity.dx - 2 * dotProduct * normal.dx) * _restitution,
        (ball.velocity.dy - 2 * dotProduct * normal.dy) * _restitution,
      );

      ball.applySquash(1.3, 0.7);
      _spawnImpactParticles(closestPoint, line.color, 10);
      return true;
    }
    return false;
  }

  void _spawnImpactParticles(Offset position, Color color, int count) {
    final random = Random();
    for (int i = 0; i < count; i++) {
      final double angle = random.nextDouble() * 2 * pi;
      final double speed = random.nextDouble() * _particleExplosionPower + 50.0;
      final double size = random.nextDouble() * 6.0 + 3.0;

      _particles.add(
        Particle(
          position: position,
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          color: color,
          size: size,
          maxLifespan: random.nextDouble() * 0.4 + 0.3,
        ),
      );
    }
  }

  void _addNewBall(Offset position, Offset direction) {
    double speed = direction.distance * 2.5;
    speed = max(100.0, min(speed, 900.0));

    final Offset initVelocity = (direction.distance == 0)
        ? const Offset(150, -150)
        : (direction / direction.distance) * speed;

    final random = Random();
    final double r = random.nextDouble() * 12.0 + 12.0;

    _balls.add(
      Ball(
        position: position,
        velocity: initVelocity,
        radius: r,
        color: _selectedBallColor,
        skin: _selectedSkin,
      ),
    );

    _spawnImpactParticles(position, _selectedBallColor, 15);
    HapticFeedback.heavyImpact();
    _canvasRepaintNotifier.value++;
  }

  void _clearCustomLines() {
    _lineObstacles.clear();
    _canvasRepaintNotifier.value++;
  }

  // Draw or interaction events
  void _handlePanStart(DragStartDetails details) {
    final Offset localPos = details.localPosition;

    if (_activeTool == 'erase') {
      _eraseAtPoint(localPos);
    } else {
      _dragStart = localPos;
      _dragEnd = localPos;
    }
    _canvasRepaintNotifier.value++;
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    final Offset localPos = details.localPosition;

    if (_activeTool == 'erase') {
      _eraseAtPoint(localPos);
    } else if (_activeTool == 'draw' && _dragStart != null) {
      _dragEnd = localPos;
    } else {
      _dragEnd = localPos;
    }
    _canvasRepaintNotifier.value++;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_dragStart != null && _dragEnd != null) {
      final Offset dragVector = _dragEnd! - _dragStart!;

      if (_activeTool == 'shoot') {
        _addNewBall(_dragStart!, -dragVector);
      } else if (_activeTool == 'draw') {
        if (dragVector.distance > 8.0) {
          _lineObstacles.add(
            LineObstacle(
              start: _dragStart!,
              end: _dragEnd!,
              color: _currentThemeColor,
            ),
          );
        }
      }
    }

    _dragStart = null;
    _dragEnd = null;
    _canvasRepaintNotifier.value++;
  }

  void _eraseAtPoint(Offset point) {
    _lineObstacles.removeWhere((line) {
      final Offset ab = line.end - line.start;
      final Offset ap = point - line.start;
      final double abLenSq = ab.dx * ab.dx + ab.dy * ab.dy;
      if (abLenSq == 0) return false;

      double t = (ap.dx * ab.dx + ap.dy * ab.dy) / abLenSq;
      t = max(0.0, min(1.0, t));
      final Offset closest = line.start + ab * t;
      return (point - closest).distance < 25.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F0B1E),
            Color(0xFF141332),
            Color(0xFF070512),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'PHYSICS BOUNCE',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.0,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.cyanAccent, blurRadius: 10),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.amberAccent),
              tooltip: 'Reset Simulation',
              onPressed: _resetDemoEnvironment,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: 'Clear Drawn lines',
              onPressed: _clearCustomLines,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Main Interactive Canvas
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.03 * 255).round()),
                        border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round()), width: 1.5),
                      ),
                      child: GestureDetector(
                        onPanStart: _handlePanStart,
                        onPanUpdate: _handlePanUpdate,
                        onPanEnd: _handlePanEnd,
                        child: RepaintBoundary(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // 1. Static/reusable background space grid
                              if (_showGrid)
                                CustomPaint(
                                  size: Size.infinite,
                                  painter: GridPainter(themeColor: _currentThemeColor),
                                ),
                              // 2. High performance separate drawing/bumper/ball layer (fully optimized updates via RepaintNotifier)
                              CustomPaint(
                                size: Size.infinite,
                                painter: CustomCanvasPainter(
                                  repaint: _canvasRepaintNotifier,
                                  balls: _balls,
                                  obstacles: _obstacles,
                                  lineObstacles: _lineObstacles,
                                  dragStart: _dragStart,
                                  dragEnd: _dragEnd,
                                  themeColor: _currentThemeColor,
                                ),
                              ),
                              // 3. High performance separate particle layer (fully optimized updates via RepaintNotifier)
                              CustomPaint(
                                size: Size.infinite,
                                painter: ParticlePainter(
                                  repaint: _canvasRepaintNotifier,
                                  particles: _particles,
                                ),
                              ),
                              // Helper tutorial banner
                              ValueListenableBuilder<int>(
                                valueListenable: _canvasRepaintNotifier,
                                builder: (context, val, child) {
                                  if (_balls.isEmpty) {
                                    return Center(
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        margin: const EdgeInsets.symmetric(horizontal: 40),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withAlpha((0.75 * 255).round()),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.cyanAccent.withAlpha((0.4 * 255).round())),
                                        ),
                                        child: const Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.touch_app, color: Colors.cyanAccent, size: 40),
                                            SizedBox(height: 10),
                                            Text(
                                              'All balls cleared! Drag & Pull anywhere to shoot new neon balls, or toggle drawing tools below.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(color: Colors.white70, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Glassmorphic Control panel
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B3A).withAlpha((0.9 * 255).round()),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round())),
        boxShadow: [
          BoxShadow(
            color: _currentThemeColor.withAlpha((0.2 * 255).round()),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Tool Selections
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildToolButton('shoot', 'Shoot Ball', Icons.sports_baseball, Colors.cyanAccent),
              _buildToolButton('draw', 'Draw Wall', Icons.gesture, Colors.pinkAccent),
              _buildToolButton('erase', 'Eraser', Icons.cleaning_services, Colors.orangeAccent),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),

          // Row 2: Live Physics Sliders (Collapsible settings)
          ExpansionTile(
            title: const Text(
              'Physics Settings & Modifiers',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            collapsedIconColor: Colors.white,
            iconColor: _currentThemeColor,
            childrenPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            children: [
              // Gravity Slider
              _buildSliderRow(
                'Vertical Gravity',
                _gravityY,
                0.0,
                800.0,
                (val) => setState(() => _gravityY = val),
                '${_gravityY.toStringAsFixed(0)} px/s²',
              ),
              // Wind Slider
              _buildSliderRow(
                'Wind Force',
                _windPower,
                -300.0,
                300.0,
                (val) => setState(() => _windPower = val),
                '${_windPower.toStringAsFixed(0)} px/s²',
              ),
              // Bounce Elasticity
              _buildSliderRow(
                'Restitution (Bounce)',
                _restitution,
                0.2,
                1.1,
                (val) => setState(() => _restitution = val),
                _restitution.toStringAsFixed(2),
              ),
              const Divider(color: Colors.white12),

              // Toggle Switches
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _buildToggleChip('Black Hole Vortex', _enableVortex, (v) {
                    setState(() {
                      _enableVortex = v;
                      _recreateObstaclesInternal();
                    });
                  }),
                  _buildToggleChip('Teleporters', _enableTeleporters, (v) {
                    setState(() {
                      _enableTeleporters = v;
                      _recreateObstaclesInternal();
                    });
                  }),
                  _buildToggleChip('Neon Bumpers', _enableBumpers, (v) {
                    setState(() {
                      _enableBumpers = v;
                      _recreateObstaclesInternal();
                    });
                  }),
                  _buildToggleChip('Ball Collisions', _ballToBallCollision, (v) {
                    setState(() => _ballToBallCollision = v);
                  }),
                  _buildToggleChip('Futuristic Grid', _showGrid, (v) => setState(() => _showGrid = v)),
                ],
              ),
            ],
          ),

          const Divider(color: Colors.white24, height: 16),

          // Row 3: Neon Skin & Theme Customizer
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BALL SKIN', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<BallSkin>(
                        value: _selectedSkin,
                        dropdownColor: const Color(0xFF1B1B3A),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        items: BallSkin.values.map((skin) {
                          return DropdownMenuItem(
                            value: skin,
                            child: Text(skin.name.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedSkin = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('BALL COLOR', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 28,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableColors.length,
                        itemBuilder: (context, index) {
                          final col = _availableColors[index];
                          final isSel = _selectedBallColor == col;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedBallColor = col),
                            child: Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: isSel ? Border.all(color: Colors.white, width: 2.0) : null,
                                boxShadow: [
                                  BoxShadow(color: col.withAlpha((0.4 * 255).round()), blurRadius: 4),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(String tool, String label, IconData icon, Color color) {
    final bool active = _activeTool == tool;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTool = tool;
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withAlpha((0.2 * 255).round()) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? color : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: active ? color : Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, ValueChanged<double> onChange, String displayVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 5,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _currentThemeColor,
                inactiveTrackColor: Colors.white12,
                thumbColor: Colors.white,
                overlayColor: _currentThemeColor.withAlpha((0.2 * 255).round()),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChange,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              displayVal,
              textAlign: TextAlign.end,
              style: TextStyle(color: _currentThemeColor, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip(String label, bool active, ValueChanged<bool> onToggle) {
    return FilterChip(
      label: Text(label),
      selected: active,
      onSelected: onToggle,
      backgroundColor: Colors.white10,
      selectedColor: _currentThemeColor.withAlpha((0.3 * 255).round()),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: active ? Colors.white : Colors.white70,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: active ? _currentThemeColor : Colors.white12),
      ),
    );
  }
}
