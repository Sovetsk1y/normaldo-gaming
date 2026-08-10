import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class HugeItem extends SpriteComponent
    with
        HasGameRef<PullUpGame>,
        CollisionCallbacks,
        Item,
        CleanScreenItem,
        KillingItem {
  @override
  bool get autoRemove => true;

  @override
  bool get collidable => true;

  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.9),
        parentSize: size,
      );

  @override
  Items get item => Items.hugeItem;

  @override
  bool get moving => true;

  @override
  double get speed => 0;

  @override
  void Function()? get onRemoved => null;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Normaldo && !other.immortal) {
      cleanScreen();
      removeFromParent();
      kill(other);
    }
  }

  @override
  FutureOr<void> onLoad() async {
    final spritePaths = [
      'punch.png',
      'trash_bin.png',
      'homeless1.png',
      'homeless2.png',
    ];
    sprite =
        await Sprite.load(spritePaths[Random().nextInt(spritePaths.length)]);
    return super.onLoad();
  }
}
