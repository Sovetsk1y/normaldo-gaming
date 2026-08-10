import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/leatherhead/leatherhead.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

enum TailSide { bottom, top }

final class LeatherheadTailAttack extends BossAttack with HasNgAudio {
  LeatherheadTailAttack({
    required this.side,
    required this.speed,
    this.endDelay = 0,
  })  : _completed = false,
        _inProgress = false;

  final double endDelay;
  final double speed;
  final TailSide side;

  bool _completed;
  bool _inProgress;

  @override
  bool get completed => _completed;

  @override
  bool get inProgress => _inProgress;

  Leatherhead bossComp(Boss boss) => boss as Leatherhead;

  Vector2 startPositionFromSide(Grid grid) => switch (side) {
        TailSide.bottom => Vector2(-150, grid.size.y - 100),
        TailSide.top => Vector2(grid.size.x + 150, 100),
      };
  Vector2 moveDestinationFromSide(Grid grid) => switch (side) {
        TailSide.bottom => Vector2(grid.size.x + 150, grid.size.y - 70),
        TailSide.top => Vector2(-150, 70),
      };
  double startTailAngleFromSide(Grid grid) => switch (side) {
        TailSide.bottom => pi / 2,
        TailSide.top => 3 * pi / 2,
      };

  @override
  void start(Boss boss, Grid grid) async {
    _inProgress = true;
    boss.position = Vector2(grid.size.x + boss.size.x, grid.size.y / 2);
    boss.scale = Vector2.all(2);
    // Initializing a tail
    final tail = LeatherheadTail()
      ..size = Vector2(grid.height / 1.2, grid.height / 1.2 / 2.28)
      ..angle = startTailAngleFromSide(grid)
      ..anchor = Anchor.bottomCenter
      ..position = startPositionFromSide(grid);
    boss.gameRef.audio.playAssetSfx('audio/bosses/leatherhead/SEA TAIL.mp3');
    grid.add(tail);
    tail.add(MoveToEffect(
        moveDestinationFromSide(grid),
        EffectController(
          speed: speed,
          curve: Curves.ease,
        ), onComplete: () {
      _completed = true;
      _inProgress = false;
      grid.remove(tail);
    }));
  }

  void _flipIfNeeded(Boss boss, Normaldo normaldo) {
    if (boss.center.x > normaldo.center.x && boss.isFlippedHorizontally) {
      boss.flipHorizontallyAroundCenter();
    }
    if (boss.center.x < normaldo.center.x && !boss.isFlippedHorizontally) {
      boss.flipHorizontallyAroundCenter();
    }
  }
}

final class LeatherheadTail extends SpriteComponent
    with CollisionCallbacks, HasGameRef<PullUpGame> {
  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Normaldo) {
      other.takeHit();
      gameRef.audio.playAssetSfx('audio/bosses/leatherhead/haha tail.mp3');
    }
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('bosses/leatherhead_tail.png');
    add(RectangleHitbox.relative(Vector2(0.9, 0.5), parentSize: size)
      ..debugColor = Colors.blue);
    return super.onLoad();
  }
}
