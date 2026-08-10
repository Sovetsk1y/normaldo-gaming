import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/item_effects/change_line_effect.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Molotov extends SpriteAnimationComponent
    with
        CollisionCallbacks,
        HasGameRef<PullUpGame>,
        Item,
        AttackingItem,
        ChangeLineEffect {
  @override
  int get damage => 1;

  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.3),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.molotov;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    attack(other);
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    strength = 1;
    final sprites = [
      await Sprite.load('molotov1.png'),
      // await Sprite.load('molotov2.png'),
    ];
    final animation = SpriteAnimation.spriteList(
      sprites,
      stepTime: 0.5,
    );
    add(SpriteAnimationComponent(
      animation: animation,
      anchor: anchor,
      size: size,
      position: size / 2,
    ));

    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (position.x <
            gameRef.size.x -
                (Random().nextInt(gameRef.size.x ~/ 2) + size.x * 2) &&
        !lineChanged) {
      changeLine();
    }
    super.update(dt);
  }
}
