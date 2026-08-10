import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class RoadSign extends SpriteComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, AttackingItem {
  @override
  Items get item => Items.roadSign;

  @override
  int get damage => 1;

  @override
  ShapeHitbox get hitbox => PolygonHitbox(
        [
          // 1
          Vector2(size.x * 0.21, size.y * 0.15),
          // 2
          Vector2(size.x * 0.7, size.y * 0.25),
          // 3
          Vector2(size.x * 0.54, size.y * 0.4),
          // 4
          Vector2(size.x * 0.84, size.y * 0.72),
          // 5
          Vector2(size.x * 0.8, size.y * 0.76),
          // 6
          Vector2(size.x * 0.49, size.y * 0.44),
          // 7
          Vector2(size.x * 0.28, size.y * 0.58),
        ],
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
    strength = 2;
    super.onLoad();
    sprite = await Sprite.load('road_sign.png');
  }
}
