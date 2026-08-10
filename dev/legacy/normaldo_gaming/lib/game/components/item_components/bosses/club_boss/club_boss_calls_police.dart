import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';
import 'package:normaldo_gaming/game/components/item_components/policeman.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';

final class ClubBossCallsPolice extends BossAttack with HasNgAudio {
  ClubBossCallsPolice()
      : _completed = false,
        _inProgress = false;

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
    final phone = SpriteComponent(
      sprite: bossComp(boss).phoneSprite,
      size: boss.size / 2,
      anchor: Anchor.center,
      position: boss.size / 1.3,
    );
    boss.add(phone);
    boss.add(MoveByEffect(
        Vector2(-boss.size.x * 2, 0),
        EffectController(
          duration: 1,
        ), onComplete: () {
      bossComp(boss).current = ClubBossState.callPolice;
      phone.flipHorizontallyAroundCenter();
      phone.position = Vector2(-phone.size.x / 3, boss.size.y / 2);
      final yIndexes = [0, 1, 2, 3, 4];
      grid.addAll([
        Policeman()
          ..speed = 300
          ..size = Items.policeman.getSize(grid.lineSize)
          ..position = Vector2(grid.size.x + boss.size.x * 1,
              grid.linesCentersY[yIndexes.random()]),
        Policeman()
          ..speed = 300
          ..size = Items.policeman.getSize(grid.lineSize)
          ..position = Vector2(grid.size.x + boss.size.x * 3,
              grid.linesCentersY[yIndexes.random()]),
        Policeman()
          ..speed = 300
          ..size = Items.policeman.getSize(grid.lineSize)
          ..position = Vector2(grid.size.x + boss.size.x * 5,
              grid.linesCentersY[yIndexes.random()]),
        Policeman()
          ..speed = 300
          ..size = Items.policeman.getSize(grid.lineSize)
          ..position = Vector2(grid.size.x + boss.size.x * 7,
              grid.linesCentersY[yIndexes.random()]),
        Policeman()
          ..speed = 300
          ..size = Items.policeman.getSize(grid.lineSize)
          ..position = Vector2(grid.size.x + boss.size.x * 9,
              grid.linesCentersY[yIndexes.random()]),
      ]);
      boss.gameRef.audio.playAssetSfx('audio/bosses/nigga_boss/NEED HELP.mp3');
      boss.addAll([
        ScaleEffect.to(
            Vector2.all(1.1),
            EffectController(
              duration: 0.1,
              reverseDuration: 0.1,
              repeatCount: 4,
            )),
        RotateEffect.by(
            0.3,
            EffectController(
              duration: 0.1,
              reverseDuration: 0.1,
              repeatCount: 4,
            ))
      ]);
      boss.add(TimerComponent(
          period: 1,
          removeOnFinish: true,
          onTick: () {
            phone.flipHorizontallyAroundCenter();
            phone.position = boss.size / 1.3;
            bossComp(boss).current = ClubBossState.idle;
            boss.add(
              MoveByEffect(
                Vector2(boss.size.x * 2, 0),
                EffectController(duration: 1),
                onComplete: () {
                  boss.remove(phone);
                  _completed = true;
                  _inProgress = false;
                },
              ),
            );
          }));
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
