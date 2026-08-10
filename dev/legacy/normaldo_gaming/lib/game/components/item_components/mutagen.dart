import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Mutagen extends SpriteComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, CustomEffectItem {
  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.8),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.mutagen;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Normaldo) {
      gameRef.sfxPools.playSfx(item);
      applyEffect(() {
        gameRef.grid.normaldo.toMaxFat();
        removeFromParent();
      });
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('mutagen.png');
    add(RotateEffect.by(
        pi * 2,
        EffectController(
          infinite: true,
          speed: 5,
        )));
    return super.onLoad();
  }
}
