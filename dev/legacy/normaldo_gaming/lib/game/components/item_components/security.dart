import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

enum Direction { up, down }

final class Security extends PositionComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, AttackingItem {
  Security({
    this.called = false,
    this.direction,
  }) {
    debugMode = false;
  }
  @override
  Items get item => Items.security;

  @override
  int get damage => 1;

  @override
  ShapeHitbox get hitbox => CircleHitbox.relative(
        0.6,
        parentSize: size,
        anchor: anchor,
      );

  late final SpriteComponent _security;

  // if this policeman was called by another so this one wouldn't call another one
  final bool called;
  final Direction? direction;

  bool _gotHelp = false;

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
    strength = 1;
    final sprite = await Sprite.load('securiti.png');
    add(_security = SpriteComponent(
      sprite: sprite,
      size: size,
      anchor: anchor,
      position: size / 2,
    ));
    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (position.x < game.grid.size.x && !_gotHelp && !called) {
      _gotHelp = true;
      _getHelp();
    }
    super.update(dt);
  }

  void _getHelp() {
    _security.addAll([
      RotateEffect.by(
          0.05 * (Random().nextBool() ? 1 : -1),
          EffectController(
            duration: 0.1,
            reverseDuration: 0.1,
            infinite: true,
            startDelay: 0.3,
          )),
      TimerComponent(
          period: 1,
          removeOnFinish: true,
          onTick: () {
            _security.removeWhere((component) => component is RotateEffect);
            _security.angle = 0;
            final yCenters = game.grid.linesCentersY;
            double closestYCenter = 1000;
            for (final yCenter in yCenters) {
              if ((yCenter - center.y).abs() < closestYCenter) {
                closestYCenter = yCenter;
              }
            }

            final currentCenterIndex = yCenters.indexOf(closestYCenter);
            Direction? nextDirection;
            if (direction != null) {
              nextDirection = direction;
              if (nextDirection == Direction.up && currentCenterIndex == 0) {
                return;
              }
              if (nextDirection == Direction.down && currentCenterIndex == 4) {
                return;
              }
            }
            if (nextDirection == null) {
              if (currentCenterIndex == 0) {
                nextDirection = Direction.down;
              } else if (currentCenterIndex == 4) {
                nextDirection = Direction.up;
              } else {
                nextDirection = Direction.values.random();
              }
            }

            final yPos = switch (nextDirection) {
              Direction.down => position.y + gameRef.grid.lineSize,
              Direction.up => position.y - gameRef.grid.lineSize,
            };
            final newPoliceman = Security(
              called: false,
              direction: nextDirection,
            )
              ..speed = speed
              ..anchor = anchor
              ..collidable = false;
            collidable = false;
            gameRef.audio.playAssetSfx(
                'audio/bosses/nigga_boss/SECURITY  DUPLICATE.mp3');
            game.grid.add(
              newPoliceman
                ..size = size
                ..position = position
                ..scale = Vector2.all(0)
                ..addAll([
                  ScaleEffect.to(
                      Vector2.all(1),
                      EffectController(
                        duration: 0.3,
                      )),
                  RotateEffect.by(
                      pi * 2,
                      EffectController(
                        duration: 0.3,
                      )),
                  MoveEffect.to(
                    Vector2(position.x, yPos),
                    EffectController(
                      duration: 0.4,
                    ),
                    onComplete: () {
                      newPoliceman.collidable = true;
                      collidable = true;
                    },
                  )
                ]),
            );
          })
    ]);
  }
}
