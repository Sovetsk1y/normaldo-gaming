import 'dart:ui';

import 'package:flame/components.dart';

class RoundedRectangleComponent extends ShapeComponent {
  RoundedRectangleComponent({
    required this.radius,
    super.position,
    super.size,
    super.scale,
    super.angle,
    super.anchor,
    super.children,
    super.priority,
    super.paint,
    super.paintLayers,
  });

  final Radius radius;

  @override
  void render(Canvas canvas) {
    if (renderShape) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(size.x / 2, size.y / 2),
                width: width,
                height: height,
              ),
              radius),
          paint);
    }
  }
}
