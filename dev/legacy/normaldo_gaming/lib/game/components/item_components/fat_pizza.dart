import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/item_components/pizza.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class FatPizza extends SpriteComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, CustomEffectItem {
  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.9),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.fatPizza;

  var _animationInProgress = false;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Normaldo) {
      applyEffect(() {
        _animationInProgress = true;
        gameRef.sfxPools.playSfx(item);
        final grid = game.grid;
        grid.removeAllItems(exclude: [this]);
        List<Vector2> takenPos = [];
        final lineAllocation = grid.lineXAllocation(size.x);
        // print(lineAllocation);
        add(
          ScaleEffect.to(
              Vector2.all(0),
              EffectController(
                duration: 0.2,
                reverseDuration: 0.2,
              ), onComplete: () {
            add(TimerComponent(
                period: 0.2,
                repeat: true,
                onTick: () {
                  if (!_animationInProgress) return;
                  Vector2 getPos() {
                    final pos = Vector2(
                      lineAllocation[Random().nextInt(lineAllocation.length)],
                      grid.linesCentersY[
                          Random().nextInt(grid.linesCentersY.length)],
                    );
                    if (takenPos.any((e) => e == pos)) return getPos();
                    if (takenPos.isNotEmpty && takenPos.last.y == pos.y) {
                      return getPos();
                    }
                    takenPos.add(pos);
                    return pos;
                  }

                  final pos = getPos();
                  final pizza = Pizza()..collidable = false;
                  parent?.add(pizza
                    ..size = Items.pizza.getSize(grid.lineSize)
                    ..position = Vector2(
                        grid.normaldo.position.x + 10,
                        grid.normaldo.position.y -
                            grid.normaldo.size.y / 2 -
                            size.y / 2)
                    ..add(MoveToEffect(
                      pos,
                      EffectController(
                        speed: 1000,
                        onMax: () {
                          pizza.collidable = true;
                        },
                      ),
                    )));
                }));
            add(TimerComponent(
              removeOnFinish: true,
              period: 0.2 * 8,
              onTick: () {
                _animationInProgress = false;
                removeFromParent();
              },
            ));
          }),
        );
      });
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('pizza_pack1.png');
    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (_animationInProgress) {
      final normaldo = game.grid.normaldo;
      position.x = normaldo.position.x + 10;
      position.y = normaldo.position.y - normaldo.size.y / 2 - size.y / 2;
    }
    super.update(dt);
  }
}
