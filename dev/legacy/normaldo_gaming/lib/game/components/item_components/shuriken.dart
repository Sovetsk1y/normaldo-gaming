import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

class Shuriken extends PositionComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, AttackingItem {
  final double startDelay;

  Shuriken({
    this.startDelay = 0,
  }) : super(anchor: Anchor.center) {
    moving = false;
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is! Shuriken) attack(other);
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  Future<void> onLoad() async {
    const fadeInDuration = 0.3;
    scale = Vector2.all(0);
    final grid = gameRef.grid;
    add(SpriteComponent(
      size: size,
      sprite: await Sprite.load('shuriken.png'),
    ));
    add(ScaleEffect.to(
        Vector2.all(1),
        EffectController(
          duration: fadeInDuration,
        )));
    add(RotateEffect.by(
        pi * 2,
        EffectController(
          duration: 0.5,
          infinite: true,
          startDelay: fadeInDuration,
        )));
    add(TimerComponent(
        period: fadeInDuration + startDelay,
        removeOnFinish: true,
        onTick: () {
          final nPosition = grid.normaldo.position;
          final distinction = nPosition - position;
          final destination = nPosition + (distinction * 3);
          add(MoveToEffect(
            destination,
            EffectController(speed: speed),
            onComplete: () => removeFromParent(),
          ));
        }));

    return super.onLoad();
  }

  @override
  Items get item => Items.shuriken;

  @override
  int get damage => 1;

  @override
  PositionComponent get hitbox => CircleHitbox.relative(
        0.9,
        parentSize: size,
        anchor: Anchor.center,
      );

  @override
  int get strength => 1;
}
