import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Phone extends SpriteComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, SlowingItem {
  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.8),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.phone;

  @override
  bool get moving => true;

  @override
  void Function()? get onRemoved => null;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Normaldo && !other.immortal) {
      if (!other.skin.resistanceToItems.contains(item)) {
        gameRef.sfxPools.playSfx(item);
      }
      slow();
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('phone 3.png');
    return super.onLoad();
  }
}
