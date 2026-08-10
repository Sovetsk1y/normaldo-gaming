import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/palette.dart';
import 'package:flutter/widgets.dart';

class ExplosionComponent extends PositionComponent {
  @override
  FutureOr<void> onLoad() {
    final screen = RectangleComponent(
      size: size,
      paint: Paint()..color = BasicPalette.white.color,
    )..opacity = 0;
    add(screen
      ..add(OpacityEffect.to(
          0.8,
          EffectController(
            duration: 0.2,
            reverseDuration: 0.2,
            curve: Curves.linearToEaseOut,
            onMin: () => screen.removeFromParent(),
          ))));
    return super.onLoad();
  }
}
