import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Magnet extends SpriteComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, CustomEffectItem {
  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.8),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.magnet;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Normaldo) {
      applyEffect(() {
        gameRef.sfxPools.playSfx(item);
        final items = game.grid.children.where((element) =>
            element is MoneygiveItem || element is PizzaGivingItem);
        for (final item in items) {
          if (item is Item) {
            item.collidable = false;
            item.add(TimerComponent(
                period: 0.001,
                repeat: true,
                onTick: () {
                  if (item.distance(other) < other.hitbox.radius &&
                      !item.collidable) {
                    item.collidable = true;
                    item.onCollisionStart(intersectionPoints, other);
                    return;
                  }
                  item.position.moveToTarget(other.position, 2);
                }));
          }
        }
      });
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('magnetp 2.png');
    return super.onLoad();
  }
}
