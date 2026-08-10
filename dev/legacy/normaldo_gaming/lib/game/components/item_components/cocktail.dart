import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class PurpleCocktail extends SpriteComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, SlowingItem {
  @override
  ShapeHitbox get hitbox => CircleHitbox.relative(
        0.9,
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.cocktail;

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
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('cocktail.png');
    return super.onLoad();
  }
}
