import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Pizza extends SpriteComponent
    with
        CollisionCallbacks,
        HasGameRef<PullUpGame>,
        Item,
        PizzaGivingItem,
        Eatable {
  @override
  ShapeHitbox get hitbox => CircleHitbox.relative(
        0.8,
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.pizza;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Normaldo) {
      gameRef.sfxPools.playSfx(item);
      givePizza();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('pizza.png');
    return super.onLoad();
  }
}
