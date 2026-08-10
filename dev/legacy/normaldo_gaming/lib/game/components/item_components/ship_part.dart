import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class ShipPart extends SpriteComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, AttackingItem {
  @override
  Items get item => Items.shipPart;

  @override
  int get damage => 2;

  @override
  ShapeHitbox get hitbox => CircleHitbox.relative(
        0.6,
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
    strength = 2;
    sprite = await Sprite.load('shippart.png');
    add(RotateEffect.to(
        2 * pi,
        EffectController(
          infinite: true,
          speed: 1,
        )));
    return super.onLoad();
  }
}
