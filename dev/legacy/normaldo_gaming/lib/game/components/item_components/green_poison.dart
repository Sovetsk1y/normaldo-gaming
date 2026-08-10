import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class GreenPoison extends SpriteComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, SlowingItem {
  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.8),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.greenPoison;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Normaldo && !other.immortal) {
      if (!other.skin.resistanceToItems.contains(item)) {
        gameRef.sfxPools.playSfx(Items.cocktail);
      }
      slow();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('colba.png');
    return super.onLoad();
  }
}
