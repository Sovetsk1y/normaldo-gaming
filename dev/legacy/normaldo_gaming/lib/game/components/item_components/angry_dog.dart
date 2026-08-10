import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class AngryDog extends SpriteComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, AttackingItem {
  @override
  int get damage => 1;

  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.9),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.angryDog;

  late final RotateEffect _shakeEffect;

  bool _hitting = false;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    attack(other);
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    strength = 2;
    sprite = await Sprite.load('angry dog 2.png');

    _shakeEffect = RotateEffect.to(
        0.5,
        EffectController(
          speed: 50,
          reverseSpeed: 50,
          infinite: true,
        ));
    final grid = game.grid;
    grid.stopLine(grid.linesCentersY.indexOf(position.y));
    grid.removeWhere((component) =>
        component is PositionComponent &&
        component.position.y == position.y &&
        component.position.x > position.x);

    add(_shakeEffect);
    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (_hitting) return;
    final grid = game.grid;
    if (position.x <= grid.size.x - (size.x / 2)) {
      gameRef.sfxPools.playSfx(item);
      _hitting = true;
      add(TimerComponent(
          period: 1,
          removeOnFinish: true,
          onTick: () {
            remove(_shakeEffect);
            add(TimerComponent(
                period: 0.5,
                removeOnFinish: true,
                onTick: () {
                  add(MoveToEffect(
                      Vector2(-grid.size.x / 2, y),
                      EffectController(
                          duration: 1,
                          onMax: () {
                            grid.resumeLines();
                            removeFromParent();
                          })));
                }));
          }));
    }
    super.update(dt);
  }
}
