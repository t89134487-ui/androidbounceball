import 'package:flutter/material.dart';
import 'widgets/physics_playground.dart';

void main() {
  runApp(const BouncyBallApp());
}

class BouncyBallApp extends StatelessWidget {
  const BouncyBallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neon Physics Bouncer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: const Color(0xFF0F0B1E),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.cyanAccent,
          surface: Color(0xFF1B1B3A),
        ),
      ),
      home: const PhysicsPlayground(),
    );
  }
}
