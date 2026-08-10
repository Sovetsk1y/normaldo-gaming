import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class PoliceCar extends SpriteComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, AttackingItem {
  @override
  Items get item => Items.trashBin;

  @override
  int get damage => 3;

  @override
  Color get debugColor => Colors.blue;

  @override
  PositionComponent get hitbox => RectangleHitbox.relative(
        Vector2(0.9, 0.3),
        parentSize: size,
        anchor: anchor,
      )..debugColor = Colors.blue;

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
    strength = 3;
    sprite = await Sprite.load('police car.png');
    return super.onLoad();
  }
}
