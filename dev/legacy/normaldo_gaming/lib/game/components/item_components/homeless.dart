import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/widgets.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Homeless extends SpriteComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, AttackingItem {
  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.9),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.homeless;

  @override
  int get damage => 1;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    attack(other);
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    const duration = 0.3;
    strength = 1;
    final isBottomJump = Random().nextBool();
    final random = Random();
    final grid = game.grid;
    final start = 1 + random.nextInt(3).toDouble() + random.nextDouble();
    sprite = await Sprite.load('homeless${isBottomJump ? 1 : 2}.png');
    add(
      TimerComponent(
          period: start,
          repeat: true,
          onTick: () {
            add(RotateEffect.to(
                pi * 2 * (random.nextBool() ? -1 : 1),
                EffectController(
                  duration: duration,
                  reverseDuration: duration,
                  // curve: Curves.easeInOutCubicEmphasized,
                  curve: Curves.easeInOutCubicEmphasized,
                )));
          }),
    );
    add(
      TimerComponent(
          period: start,
          repeat: true,
          onTick: () {
            add(MoveAlongPathEffect(
                Path()
                  ..quadraticBezierTo(-size.x / 2,
                      grid.lineSize * (isBottomJump ? 1 : -1), -size.x, 0),
                EffectController(
                  duration: duration,
                  reverseDuration: duration,
                )));
          }),
    );
    return super.onLoad();
  }
}
