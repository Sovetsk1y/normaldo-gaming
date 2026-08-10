import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Umbrella extends SpriteAnimationComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, AttackingItem {
  @override
  Items get item => Items.umbrella;

  @override
  int get damage => 1;

  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
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
    final sprites = [
      await Sprite.load('umbrella.png'),
      await Sprite.load('umbrella2.png'),
    ];
    add(SpriteAnimationComponent(
      animation: SpriteAnimation.spriteList(sprites, stepTime: 0.5),
      size: size,
    ));
    return super.onLoad();
  }
}
