import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Bullet extends SpriteComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, AttackingItem {
  final Vector2? destination;
  final double? animationSpeed;

  Bullet({
    this.destination,
    this.animationSpeed = 1000,
  });

  @override
  Items get item => Items.bullet;

  @override
  int get damage => 1;

  @override
  Color get debugColor => Colors.red;

  @override
  PositionComponent get hitbox => RectangleHitbox.relative(
        Vector2.all(0.9),
        parentSize: size,
        anchor: anchor,
      );

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    attack(other);
  }

  @override
  FutureOr<void> onLoad() async {
    strength = 1;
    sprite = await Sprite.load('bosses/bullet.png');
    moving = false;

    if (destination != null) {
      angle = angleTo(destination!) + (pi / 2);
    }
    if (destination != null) {
      add(MoveToEffect(
        destination!,
        EffectController(speed: animationSpeed),
        onComplete: () => removeFromParent(),
      ));
    }
    return super.onLoad();
  }
}
