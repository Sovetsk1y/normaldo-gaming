import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/widgets.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Cannibal extends SpriteComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, AttackingItem {
  @override
  int get damage => 1;

  @override
  ShapeHitbox get hitbox => CircleHitbox.relative(
        0.8,
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.cannibal;

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
    strength = 1;
    const duration = 0.3;
    final random = Random();
    final start = 1 + random.nextInt(3).toDouble() + random.nextDouble();
    sprite = await Sprite.load('canibal.png');
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
                  curve: Curves.easeInOutCubicEmphasized,
                )));
          }),
    );
    add(
      TimerComponent(
          period: start,
          repeat: true,
          onTick: () {
            add(MoveEffect.by(
                Vector2(-size.x * 1.5, 0),
                EffectController(
                  duration: duration,
                  reverseDuration: duration,
                )));
          }),
    );
    return super.onLoad();
  }
}
