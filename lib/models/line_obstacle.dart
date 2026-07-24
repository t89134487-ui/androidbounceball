import 'package:flutter/material.dart';

class LineObstacle {
  final Offset start;
  final Offset end;
  final Color color;
  final double thickness;

  LineObstacle({
    required this.start,
    required this.end,
    required this.color,
    this.thickness = 5.0,
  });
}
