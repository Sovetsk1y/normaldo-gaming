import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/foundation.dart';
import 'package:normaldo_gaming/core/roller/roller.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/effects/effects.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';
import './attack.dart';

final class CloneAttack extends Attack with Effects {
  CloneAttack({
    required this.cloneSprites,
    required this.wavesPeriod,
    required this.wavesAmount,
    this.onNewWave,
  })  : assert(wavesAmount > 0 && wavesPeriod > 0),
        assert(cloneSprites.isNotEmpty);

  final Set<Sprite> cloneSprites;
  final double wavesPeriod;
  final int wavesAmount;
  final ValueChanged<int>? onNewWave;
  final _rnd = Random();

  TimerComponent? _wavesTimer;

  int _tick = 0;
  int _wave = 0;

  Sprite get _cloneSprite {
    if (cloneSprites.length == 1) {
      return cloneSprites.first;
    } else {
      return cloneSprites.toList()[_rnd.nextInt(cloneSprites.length)];
    }
  }

  @override
  void pause(Boss boss) {
    _wavesTimer?.timer.pause();
  }

  @override
  void run(Boss boss) {
    assert(_wavesTimer == null, '_wavesTimer != null');
    inProgress = true;
    boss.position =
        Vector2(boss.game.size.x - boss.size.x, boss.game.size.y / 2);
    boss.add(fadeInEffect(duration: 0.2));
    _wavesTimer = TimerComponent(
      period: wavesPeriod,
      repeat: true,
      onTick: () {
        if (_tick >= wavesAmount / 3 && !hasNormaldoAttack) {
          hasNormaldoAttack = true;
          // final punch = SlakeBakeAttack();
          // boss.game.grid.add(
          //   punch
          //     ..position =
          //         Vector2(boss.position.x, boss.position.y - boss.size.y)
          //     ..size = Items.fistPunch.getSize(boss.game.grid.lineSize),
          // );
          // punch.add(RemoveEffect(delay: 10));
          // punch.add(OpacityEffect.to(
          //     punch.opacity == 1 ? 0 : 1,
          //     EffectController(
          //       startDelay: 0.3,
          //       duration: 0.3,
          //       reverseDuration: 0.3,
          //       repeatCount: 10,
          //     ), onComplete: () {
          //   punch.add(SequenceEffect([
          //     scaleOutEffect(),
          //     RemoveEffect(),
          //   ]));
          // }));
        }
        if (_tick >= wavesAmount) {
          _wavesTimer?.timer.stop();
          _wavesTimer = null;
          stop(boss);
          return;
        }
        _tick++;
        _startWave(boss);
      },
    );
    boss.add(_wavesTimer!);
  }

  void _startWave(Boss boss) {
    var startPositions = List<double>.from(boss.game.grid.linesCentersY);
    startPositions.removeAt(Random().nextInt(startPositions.length));
    final removeOneMore = Roller<bool>([(true, 2), (true, 1)]).roll();
    if (removeOneMore) {
      // startPositions.removeAt(Random().nextInt(startPositions.length));
      final pos = startPositions[_rnd.nextInt(startPositions.length)];
      startPositions = [pos];
    }
    // final amount = Utils.linesCount - (removeOneMore ? 2 : 1);
    final amount = 1;
    for (var i = 0; i < amount; i++) {
      final nextIndex = Random().nextInt(startPositions.length);
      final clone = _CloneComponent(
        _cloneSprite,
        size: boss.size * 0.9,
        position: boss.position,
        anchor: Anchor.center,
        scale: Vector2.all(0),
        onAttack: () {
          stop(boss);
        },
      )..collidable = false;
      boss.game.grid.add(
        clone
          ..moving = false
          ..addAll(
            jumpToEffect(
                duration: 0.2,
                position: Vector2(
                  boss.position.x,
                  startPositions.removeAt(nextIndex),
                ),
                onComplete: () {
                  clone.moving = true;
                  clone.collidable = true;
                  _wave++;
                  onNewWave?.call(_wave);
                }),
          )
          ..add(RotateEffect.by(
              0.2 * (Random().nextBool() ? 1 : -1),
              EffectController(
                duration: 0.2,
                reverseDuration: 0.2,
                infinite: true,
              ))),
      );
      clone.add(scaleInEffect());
    }
  }

  @override
  void stop(Boss boss) {
    _wavesTimer?.timer.stop();
    _wavesTimer = null;
    boss.game.grid.children.whereType<_CloneComponent>().forEach((element) {
      Vector2 newPosition = Vector2.all(0);
      double smallestDistance(List<double> distances) {
        double smallest = distances.first;
        for (var distance in distances) {
          if (distance < smallest) {
            smallest = distance;
          }
        }
        return smallest;
      }

      final distanceToTopLeft = element.position.distanceTo(Vector2.all(0));
      final distanceToTopRight =
          element.position.distanceTo(Vector2(boss.game.size.x, 0));
      final distanceToBottomLeft =
          element.position.distanceTo(Vector2(0, boss.game.size.y));
      final distanceToBottomRight = element.position
          .distanceTo(Vector2(boss.game.size.x, boss.game.size.y));
      final distance = smallestDistance([
        distanceToBottomLeft,
        distanceToTopLeft,
        distanceToBottomRight,
        distanceToTopRight
      ]);
      if (distance == distanceToBottomLeft) {
        newPosition = Vector2(0, boss.game.size.y) + Vector2(-100, 100);
      }
      if (distance == distanceToBottomRight) {
        newPosition =
            Vector2(boss.game.size.x, boss.game.size.y) + Vector2(100, 100);
      }
      if (distance == distanceToTopRight) {
        newPosition = Vector2(boss.game.size.x, 0) + Vector2(100, -100);
      }
      if (distance == distanceToTopLeft) {
        newPosition = Vector2(0, 0) - Vector2(100, 100);
      }
      element.addAll([
        ...jumpToEffect(
          duration: 2,
          position: newPosition,
          onComplete: () => element.removeFromParent(),
        ),
        fadeOutEffect(duration: 2),
      ]);
    });
    boss.game.grid.children.whereType<NormaldoAttack>().forEach((element) {
      element.removeFromParent();
    });
    boss.add(fadeOutEffect());
    inProgress = false;
    finished = true;
  }
}

final class _CloneComponent extends SpriteComponent
    with
        CollisionCallbacks,
        HasGameRef<PullUpGame>,
        Item,
        AttackingItem,
        Effects {
  _CloneComponent(
    this._sprite, {
    required this.onAttack,
    super.size,
    super.anchor,
    super.position,
    super.scale,
  });

  final Sprite _sprite;
  final VoidCallback onAttack;

  @override
  int get damage => 1;

  @override
  PositionComponent get hitbox => RectangleHitbox.relative(
        Vector2.all(0.8),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.trashBin;

  @override
  int get strength => 0;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Normaldo && !other.immortal) {
      attack(other);
      onAttack();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() {
    sprite = _sprite;
    return super.onLoad();
  }
}
