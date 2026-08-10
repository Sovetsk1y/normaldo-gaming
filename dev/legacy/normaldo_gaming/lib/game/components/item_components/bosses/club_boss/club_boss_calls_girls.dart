import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';
import 'package:normaldo_gaming/game/components/item_components/girl.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';

final class ClubBossCallsGirls extends BossAttack with HasNgAudio {
  ClubBossCallsGirls({this.endDelay = 0})
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
    boss.position = Vector2(grid.size.x + boss.size.x, grid.size.y / 2);
    boss.scale = Vector2.all(2);
    bossComp(boss).current = ClubBossState.callGirls;
    boss.gameRef.audio.playAssetSfx('audio/bosses/nigga_boss/TALKING 2.mp3');
    boss.add(MoveByEffect(
        Vector2(-boss.size.x * 2, 0),
        EffectController(
          duration: 1,
        ), onComplete: () {
      final girlSize = Items.girl.getSize(grid.lineSize);
      var counter = 3;
      final timerCompKey = ComponentKey.unique();
      boss.add(TimerComponent(
          period: 0.5,
          repeat: true,
          key: timerCompKey,
          onTick: () {
            if (counter == 0) {
              boss.gameRef
                  .findByKey<TimerComponent>(timerCompKey)
                  ?.timer
                  .stop();
              _completed = true;
              _inProgress = false;
              return;
            }
            counter--;
            grid.addAll(List.generate(
              5,
              (index) => Girl()
                ..size = girlSize
                ..position = Vector2(
                    grid.size.x + girlSize.x * 2, grid.linesCentersY[index]),
            ));
          }));
      boss.add(MoveByEffect(
          Vector2(boss.size.x * 2, 0),
          DelayedEffectController(
            EffectController(
              duration: 2,
            ),
            delay: 1,
          )));
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
