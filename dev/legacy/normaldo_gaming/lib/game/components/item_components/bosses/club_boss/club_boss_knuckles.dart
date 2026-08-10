import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

class ClubBossKnuckles extends PositionComponent
    with ParentIsA<ClubBoss>, HasGameRef<PullUpGame> {
  static const double rotateDur = 0.2;
  late final Vector2 leftHandPosition;
  late final Vector2 rightHandPosition;
  late final SpriteComponent leftHand;
  late final SpriteComponent rightHand;

  var _isUppercutting = false;
  var _isJabbing = false;

  Effect _appearEffect() {
    return ScaleEffect.to(
      Vector2.all(1),
      EffectController(duration: 0.1),
    );
  }

  Effect _disappearEffect() {
    return ScaleEffect.to(
      Vector2.all(0.1),
      EffectController(duration: 0.1),
    );
  }

  void knucklesDown() {
    leftHand.addAll([
      _disappearEffect(),
      MoveEffect.to(
          parent.size / 2,
          EffectController(
            duration: 0.1,
          )),
      RotateEffect.to(-1, EffectController(duration: rotateDur)),
    ]);
    rightHand.addAll([
      _disappearEffect(),
      MoveEffect.to(
          parent.size / 2,
          EffectController(
            duration: 0.1,
          )),
      RotateEffect.to(1, EffectController(duration: rotateDur), onComplete: () {
        removeFromParent();
      }),
    ]);
  }

  void uppercut() {
    if (_isJabbing) return;
    if (_isUppercutting) return;
    const double dur = 0.1;
    const double atMaxDur = 0.5;
    _isUppercutting = true;
    rightHand.removeWhere((component) => component is Effect);
    rightHand.angle = 0;

    rightHand.addAll([
      MoveByEffect(
          Vector2(-parent.size.x / 2, parent.size.y / 2),
          EffectController(
            duration: dur,
            atMaxDuration: atMaxDur,
            reverseDuration: dur,
          )),
      RotateEffect.by(
          1.5,
          EffectController(
            duration: dur,
            atMaxDuration: atMaxDur,
            reverseDuration: dur,
          ), onComplete: () {
        _isUppercutting = false;
        _animateRightHandIdle();
      }),
    ]);
  }

  @override
  FutureOr<void> onLoad() async {
    size = parent.size;
    leftHandPosition = Vector2(15, 0);
    rightHandPosition = Vector2(size.x - 20, 5);
    await Sprite.load('bosses/club_boss_knuckle.png');
    leftHand = _Hand(
      sprite: await Sprite.load('bosses/club_boss_knuckle.png'),
    )
      ..anchor = Anchor.topRight
      ..angle = -1;
    rightHand = _Hand(
      sprite: await Sprite.load('bosses/club_boss_right_knuckle.png'),
    )..angle = 1;

    // Debug mode
    const debugMode = false;
    leftHand.debugMode = debugMode;
    rightHand.debugMode = debugMode;

    addAll([
      leftHand
        ..addAll([
          _appearEffect(),
          MoveEffect.to(
              leftHandPosition,
              EffectController(
                duration: 0.1,
              )),
          RotateEffect.to(0, EffectController(duration: rotateDur)),
        ]),
      rightHand
        ..addAll([
          _appearEffect(),
          MoveEffect.to(
              rightHandPosition,
              EffectController(
                duration: 0.1,
              )),
          RotateEffect.to(0, EffectController(duration: rotateDur)),
        ]),
    ]);

    _animateLeftHandIdle();

    leftHand.add(TimerComponent(
        period: 2,
        repeat: true,
        onTick: () {
          if (_isUppercutting) return;
          _isJabbing = true;
          leftHand.addAll([
            MoveEffect.by(
                Vector2(-30, 0),
                EffectController(
                  duration: 0.1,
                  atMaxDuration: 0.1,
                  reverseDuration: 0.1,
                )),
            ScaleEffect.to(
                Vector2.all(1.5),
                EffectController(
                  duration: 0.1,
                  atMaxDuration: 0.1,
                  reverseDuration: 0.1,
                ), onComplete: () {
              _isJabbing = false;
            }),
          ]);
        }));
    rightHand.add(TimerComponent(
      period: 3,
      repeat: true,
      onTick: () {
        uppercut();
      },
    ));
    _animateRightHandIdle();
    return super.onLoad();
  }

  void _animateLeftHandIdle() {
    leftHand.addAll([
      MoveByEffect(
          Vector2(0, 5),
          EffectController(
            infinite: true,
            duration: 0.6,
            reverseDuration: 0.6,
          )),
    ]);
  }

  void _animateRightHandIdle() {
    rightHand.addAll([
      MoveByEffect(
          Vector2(0, 10),
          EffectController(
            infinite: true,
            duration: 1,
            reverseDuration: 1,
          )),
    ]);
  }
}

class _Hand extends SpriteComponent
    with
        CollisionCallbacks,
        HasGameRef<PullUpGame>,
        ParentIsA<ClubBossKnuckles> {
  _Hand({
    required this.sprite,
  });
  @override
  final Sprite sprite;

  void attack(PositionComponent other) {
    if (other is Boss) return;
    if (other is Normaldo && !other.immortal) {
      other.takeHit(damage: 1);
      gameRef.grid.showCollisionComics(
        type: ComicsType.hurt,
        position: position,
        size: size,
      );
    }
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
  FutureOr<void> onLoad() {
    priority = 0;
    size = parent.size / 1.5;
    position = parent.size / 2;
    sprite = sprite;
    scale = Vector2.all(0.1);

    add(CircleHitbox.relative(
      0.6,
      parentSize: size,
      anchor: Anchor.center,
      position: size / 2,
    ));
    return super.onLoad();
  }
}
