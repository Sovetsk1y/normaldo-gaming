import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/widgets.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/leatherhead/leatherhead.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/ninja_foot/ninja_foot.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

mixin Boss on PositionComponent, HasGameRef<PullUpGame>, CollisionCallbacks {
  bool _bossWarned = false;
  bool get bossWarned => _bossWarned;
  List<BossAttack> attacks = [];
  List<Items> immuneToItems = [];

  void start();

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Normaldo) {
      other.takeHit();
    }
    if (other is Item && !immuneToItems.contains(other.item)) {
      other.removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  String get _path => switch (this) {
        NinjaFoot() => 'BOSSFIGHT.png',
        Leatherhead() => 'bosses/BOSSFIGHT LH.png',
        ClubBoss() => 'bosses/BOSSFIGHT FA.png',
        _ => 'BOSSFIGHT.png',
      };

  Future<void> warn() async {
    final grid = gameRef.grid;
    final warning = SpriteComponent(
      sprite: await Sprite.load(_path),
      position: Vector2(grid.size.x * 1.5, grid.center.y),
      size: game.grid.size / 2,
      anchor: Anchor.center,
    );
    add(TimerComponent(
        period: 0.3,
        removeOnFinish: true,
        onTick: () {
          gameRef.audio.playAssetSfx('audio/sfx/boss_fight.mp3');
        }));
    game.grid.add(warning
          ..add(MoveToEffect(
              grid.center,
              EffectController(
                duration: 0.5,
                curve: Curves.linearToEaseOut,
              ), onComplete: () {
            warning.add(
              ScaleEffect.to(
                  Vector2.all(1.5),
                  EffectController(
                    repeatCount: 2,
                    duration: 0.2,
                    reverseDuration: 0.2,
                  )),
            );
            warning.add(TimerComponent(
                period: 1,
                removeOnFinish: true,
                onTick: () {
                  warning.add(MoveToEffect(
                    Vector2(grid.width * -1.5, grid.center.y),
                    EffectController(
                      duration: 0.5,
                      curve: Curves.linearToEaseOut,
                    ),
                    onComplete: () {
                      game.grid.remove(warning);
                      _bossWarned = true;
                      game.grid.controlTurnedOff = false;
                    },
                  ));
                }));
          }))
        // ..add(SequenceEffect([
        //   ScaleEffect.to(
        //       Vector2.all(1),
        //       EffectController(
        //         duration: 0.2,
        //       )),
        // ScaleEffect.to(
        //     Vector2.all(1.3),
        //     EffectController(
        //       repeatCount: 2,
        //       duration: 0.2,
        //       reverseDuration: 0.2,
        //     )),
        //   ScaleEffect.to(
        //     Vector2.all(50),
        //     EffectController(
        //       startDelay: 1,
        //       duration: 0.2,
        //     ),
        //   ),
        // ], onComplete: () {
        //   game.grid.remove(warning);
        //   _bossWarned = true;
        //   game.grid.controlTurnedOff = false;
        // })),
        );
  }

  @override
  FutureOr<void> onLoad() {
    anchor = Anchor.center;
    add(CircleHitbox.relative(
      0.6,
      parentSize: size,
      anchor: anchor,
      position: size / 2,
    ));

    return super.onLoad();
  }
}
