import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/core/roller/roller.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

final class MagicBox extends SpriteComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, CustomEffectItem {
  @override
  ShapeHitbox get hitbox => CircleHitbox.relative(
        0.8,
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.magicBox;

  var _animationInProgress = false;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Normaldo) {
      applyEffect(() {
        collidable = false;
        _animationInProgress = true;
        gameRef.sfxPools.playSfx(item);
        final grid = game.grid;
        grid.removeAllItems(exclude: [this]);
        grid.stopAllLines();
        List<Vector2> takenPos = [];
        final lineAllocation = grid.lineXAllocation(size.x);
        add(
          ScaleEffect.to(
              Vector2.all(0),
              EffectController(
                duration: 0.2,
                reverseDuration: 0.2,
              ), onComplete: () {
            final key = ComponentKey.unique();
            add(TimerComponent(
                key: key,
                removeOnFinish: true,
                period: 0.2,
                repeat: true,
                onTick: () {
                  if (!_animationInProgress) return;
                  Vector2 getPos() {
                    if (lineAllocation.isEmpty) {
                      lineAllocation.addAll(grid.lineXAllocation(size.x));
                    }
                    final xPos =
                        lineAllocation[Random().nextInt(lineAllocation.length)];
                    final pos = Vector2(
                      xPos,
                      grid.linesCentersY[
                          Random().nextInt(grid.linesCentersY.length)],
                    );
                    if (takenPos.isNotEmpty && takenPos.last.y == pos.y) {
                      return getPos();
                    }
                    lineAllocation.remove(xPos);
                    takenPos.add(pos);
                    return pos;
                  }

                  final pos = getPos();
                  final allRolls = <(Items, double)>[
                    (Items.pizza, 5),
                    (Items.cocktail, 1),
                    (Items.greenPoison, 1),
                    (Items.girl, 1),
                    (Items.bananaPeel, 1),
                    (Items.beer, 1),
                    (Items.moneyBag, 0.1),
                    (Items.caseyMask, 0.5),
                    (Items.dollar, 2),
                    (Items.magicHat, 0.5),
                    (Items.hourglass, 0.5),
                    (Items.goldClocks, 0.5),
                    (Items.compass, 0.5),
                  ];
                  final availableRolls = <(Items, double)>[];
                  for (final roll in allRolls) {
                    if (gameRef.scene.currentLevel.contains(roll.$1)) {
                      availableRolls.add(roll);
                    }
                  }
                  final roller = Roller<Item>(
                    availableRolls
                        .map((e) => (e.$1.component(), e.$2))
                        .toList(),
                  );
                  final item = roller.roll()..collidable = false;
                  grid.add(item
                    ..size = item.item.getSize(grid.lineSize)
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
                          item.collidable = true;
                        },
                      ),
                    )));
                }));
            grid.add(TimerComponent(
              removeOnFinish: true,
              period: 0.2 * 8,
              onTick: () {
                _animationInProgress = false;
                gameRef.findByKey<TimerComponent>(key)?.timer.stop();
                add(ScaleEffect.to(
                    Vector2.all(0),
                    EffectController(
                      duration: 0.2,
                    )));
                grid.add(TimerComponent(
                    period: 2,
                    removeOnFinish: true,
                    onTick: () {
                      grid.resumeLines();
                      removeFromParent();
                    }));
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
    sprite = await Sprite.load('magic box 2.png');
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
