import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/game/components/effects/effects.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';

final class ClubBossTrack extends BossAttack with HasNgAudio, Effects {
  static const double duration = 13.0;

  ClubBossTrack({this.endDelay = 0})
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
    bossComp(boss).current = ClubBossState.track;
    boss.add(MoveByEffect(
        Vector2(-boss.size.x * 2, 0),
        EffectController(
          duration: 1,
        ), onComplete: () {
      boss.gameRef.audio.playAssetSfx('audio/bosses/nigga_boss/WHOS NEXT.mp3');
      boss.addAll([
        RotateEffect.by(
            0.2,
            EffectController(
              duration: 0.3,
              reverseDuration: 0.3,
              repeatCount: 2,
            ), onComplete: () {
          bossComp(boss).knucklesUp();
          bossComp(boss).tracking = true;
          boss.add(TimerComponent(
              period: duration,
              removeOnFinish: true,
              onTick: () {
                bossComp(boss).tracking = false;
                bossComp(boss).knucklesDown();
                _completed = true;
                _inProgress = false;
              }));
        }),
      ]);
    }));
  }
}
