import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/leatherhead/leatherhead.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';

final class LeatherheadBuckshot extends BossAttack with HasNgAudio {
  LeatherheadBuckshot({this.endDelay = 0})
      : _completed = false,
        _inProgress = false;

  final double endDelay;

  bool _completed;
  bool _inProgress;

  @override
  bool get completed => _completed;

  @override
  bool get inProgress => _inProgress;

  Leatherhead bossComp(Boss boss) => boss as Leatherhead;

  @override
  void start(Boss boss, Grid grid) {
    _inProgress = true;
    boss.position = Vector2(grid.size.x + boss.size.x, grid.size.y / 2);
    boss.scale = Vector2.all(2);
    bossComp(boss).current = LeatherheadState.takeGun;
    boss.add(MoveByEffect(
        Vector2(-boss.size.x * 2, 0),
        EffectController(
          duration: 1,
        ), onComplete: () {
      bossComp(boss).buckshot(onComplete: () {
        _completed = true;
        _inProgress = false;
      });
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
