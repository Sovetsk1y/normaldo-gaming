import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/services.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class Boombox extends SpriteAnimationComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, CleanScreenItem {
  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.5),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.boombox;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Normaldo) {
      gameRef.sfxPools.playSfx(item);
      HapticFeedback.heavyImpact();
      cleanScreen();
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    const duration = 0.5;
    final sprites = [
      await Sprite.load('boombox1.png'),
      await Sprite.load('boombox2.png'),
    ];
    final animation = SpriteAnimation.spriteList(
      sprites,
      stepTime: 0.2,
    );
    add(SpriteAnimationComponent(
      animation: animation,
      anchor: anchor,
      size: size,
      position: size / 2,
    ));

    add(SequenceEffect(
      [
        ScaleEffect.to(
            Vector2(1.3, 1),
            EffectController(
              duration: duration,
              reverseDuration: duration,
              atMaxDuration: 0.2,
            )),
        ScaleEffect.to(
            Vector2(1, 0.7),
            EffectController(
              duration: duration,
              reverseDuration: duration,
            )),
      ],
      infinite: true,
    ));

    return super.onLoad();
  }
}
