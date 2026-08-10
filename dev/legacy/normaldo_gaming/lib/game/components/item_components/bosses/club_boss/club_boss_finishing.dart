import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/effects/effects.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';
import 'package:normaldo_gaming/game/components/item_components/girl.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';

final class ClubBossFinishing extends BossAttack with HasNgAudio, Effects {
  ClubBossFinishing({this.endDelay = 0})
      : _completed = false,
        _inProgress = false;

  final double endDelay;

  bool _completed;
  bool _inProgress;

  @override
  bool get completed => _completed;

  @override
  bool get inProgress => _inProgress;

  ClubBoss bossComp(Boss boss) => boss as ClubBoss;

  @override
  void start(Boss boss, Grid grid) {
    _inProgress = true;
    boss.scale = Vector2.all(2);
    boss.addAll(jumpToEffect(
      position: Vector2(
        grid.size.x - boss.size.x * 2,
        grid.center.y,
      ),
      onComplete: () {
        flipIfNeeded(boss, grid.normaldo);
        boss.gameRef.audio
            .playAssetSfx('audio/bosses/nigga_boss/TALKING 2.mp3');
        boss.add(TimerComponent(
            period: 1,
            removeOnFinish: true,
            onTick: () {
              bossComp(boss).current = ClubBossState.callSecurity;
              final girls = List.generate(
                20,
                (index) {
                  final destination = boss.center +
                      Vector2(
                        Random().nextDouble() *
                            100 *
                            (Random().nextBool() ? 1 : -1),
                        Random().nextDouble() *
                            100 *
                            (Random().nextBool() ? 1 : -1),
                      );
                  final girl = Girl()
                    ..collidable = false
                    ..moving = false
                    ..size = Items.girl.getSize(grid.lineSize)
                    ..position = Vector2(
                      grid.size.x + grid.lineSize,
                      grid.center.y - grid.lineSize,
                    )
                    ..add(MoveEffect.to(
                      destination,
                      DelayedEffectController(
                        EffectController(
                          duration: 1 * Random().nextDouble(),
                        ),
                        delay: Random().nextDouble(),
                      ),
                    ));
                  return girl;
                },
              );
              grid.addAll(girls);
              boss.gameRef.audio
                  .playAssetSfx('audio/bosses/nigga_boss/kissing.mp3');
              boss.add(TimerComponent(
                  period: 2,
                  removeOnFinish: true,
                  onTick: () {
                    const double duration = 1;
                    _completed = true;
                    _inProgress = false;
                    boss.add(MoveEffect.by(
                        Vector2(Items.girl.getSize(grid.lineSize).x * 10, 0),
                        EffectController(duration: duration), onComplete: () {
                      _completed = true;
                      _inProgress = false;
                    }));
                    for (final girl in girls) {
                      girl.add(
                        MoveByEffect(Vector2(girl.width * 10, 0),
                            EffectController(duration: 1), onComplete: () {
                          if (girls.indexOf(girl) == 0) {
                            for (final girl in girls) {
                              girl.add(
                                MoveByEffect(Vector2(girl.width * 10, 0),
                                    EffectController(duration: duration)),
                              );
                            }
                          }
                        }),
                      );
                    }
                  }));
            }));
      },
    ));
    _flipIfNeeded(boss, grid.normaldo);
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
