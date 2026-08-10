import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class SpadesCard extends SpriteComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, AttackingItem {
  @override
  Items get item => Items.spadesCard;

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
    attack(other);
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    strength = 1;
    sprite = await Sprite.load('pickyCard 2.png');
    return super.onLoad();
  }
}
