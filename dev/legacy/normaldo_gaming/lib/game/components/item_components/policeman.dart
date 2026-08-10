import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/item_components/handcuffs.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

enum Direction {
  leftUp,
  up,
  rightUp,
  right,
  rightBottom,
  bottom,
  leftBottom,
  left
}

final class Policeman extends PositionComponent
    with HasGameRef<PullUpGame>, CollisionCallbacks, Item, AttackingItem {
  Policeman({this.called = false}) {
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

  late final SpriteComponent _hand;
  late final SpriteComponent _security;

  // if this policeman was called by another so this one wouldn't call another one
  final bool called;

  bool _gotHelp = false;

  Vector2 getPositionFrom(Direction direction) {
    return switch (direction) {
      Direction.leftUp => position - size,
      Direction.up => position - Vector2(0, size.y),
      Direction.rightUp => position + Vector2(size.x, -size.y),
      Direction.right => position + Vector2(size.x, 0),
      Direction.rightBottom => position + size,
      Direction.bottom => position + Vector2(0, size.y),
      Direction.leftBottom => position + Vector2(-size.x, size.y),
      Direction.left => position + Vector2(-size.x, 0)
    };
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    attack(other);
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    strength = 1;
    final sprite = await Sprite.load('policeman.png');
    add(_security = SpriteComponent(
      sprite: sprite,
      size: size,
      anchor: anchor,
      position: size / 2,
    ));
    _hand = SpriteComponent(
        sprite: await Sprite.load('policeman_calling.png'),
        anchor: anchor,
        scale: Vector2.all(0),
        size: Vector2(size.x * 0.3, size.y * 0.5));
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
    add(_hand
      ..position = Vector2(size.x * 0.8, size.y / 1.5)
      ..add(ScaleEffect.to(
          Vector2.all(1),
          EffectController(
            duration: 0.3,
            atMaxDuration: 1,
            reverseDuration: 0.3,
          ), onComplete: () {
        remove(_hand);
      })));
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

            final direction = Direction.values.random();
            final distinction = getPositionFrom(direction) - position;
            final destination = position + distinction * 10;

            final handcuffs = Handcuffs()
              ..speed = speed
              ..collidable = false;
            gameRef.audio.playAssetSfx('audio/bosses/nigga_boss/BRACERS.mp3');
            game.grid.add(
              handcuffs
                ..size = Items.handcuffs.getSize(gameRef.grid.lineSize)
                ..position = position
                ..scale = Vector2.all(0)
                ..addAll([
                  ScaleEffect.to(
                      Vector2.all(1),
                      EffectController(
                        duration: 0.3,
                      ), onComplete: () {
                    handcuffs.collidable = true;
                  }),
                  RotateEffect.by(
                      pi * 2,
                      EffectController(
                        duration: 1,
                        repeatCount: 10,
                      )),
                  MoveEffect.to(
                    destination,
                    EffectController(
                      duration: 6,
                    ),
                    onComplete: () {
                      handcuffs.removeFromParent();
                    },
                  )
                ]),
            );
          })
    ]);
  }
}
