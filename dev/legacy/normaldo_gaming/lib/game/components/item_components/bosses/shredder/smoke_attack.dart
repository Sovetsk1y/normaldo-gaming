import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/effects/effects.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/ninja_foot/ninja_foot.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/ninja_foot/smoke.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/shuriken_shower_attack.dart';

final class SmokeAttack extends BossAttack with HasNgAudio, Effects {
  SmokeAttack({
    required this.action,
    this.duration = 5,
  })  : _completed = false,
        _inProgress = false;

  final SmokeAction action;
  final double duration;
  final List<Corner> corners = [];

  bool _completed;
  bool _inProgress;

  @override
  bool get completed => _completed;

  @override
  bool get inProgress => _inProgress;

  SpriteAnimationGroupComponent<NinjaFootState> bossComp(Boss boss) =>
      boss as SpriteAnimationGroupComponent<NinjaFootState>;

  @override
  void start(Boss boss, Grid grid) {
    _inProgress = true;
    boss.scale = Vector2.all(1);
    final grid = boss.gameRef.grid;
    corners.addAll([
      Corner(position: boss.size, corner: Corners.topLeft),
      Corner(
          position: Vector2(grid.size.x - boss.size.x, boss.size.y),
          corner: Corners.topRight),
      Corner(position: grid.size - boss.size, corner: Corners.bottomRight),
      Corner(
          position: Vector2(boss.size.x, grid.size.y - boss.size.y),
          corner: Corners.bottomLeft),
    ]);
    bossComp(boss).opacity = 0;
    boss.position = Vector2(grid.size.x - boss.size.x * 1.5, grid.size.y / 2);
    boss.add(SequenceEffect([
      fadeInEffect(),
    ], onComplete: () {
      bossComp(boss).current = NinjaFootState.smoke;
      boss.add(TimerComponent(
          period: 8 * 0.1,
          removeOnFinish: true,
          onTick: () {
            grid.add(Smoke(
              corners: corners,
              duration: duration,
              action: action,
            )
              ..size = Items.smoke.getSize(grid.lineSize)
              ..position = boss.position);
            boss.add(TimerComponent(
                period: 1,
                removeOnFinish: true,
                onTick: () {
                  bossComp(boss).add(MoveByEffect(
                      Vector2(0, -500),
                      EffectController(
                        duration: 0.5,
                      )));
                  bossComp(boss).current = NinjaFootState.idle;
                  _completed = true;
                  _inProgress = false;
                }));
          }));
    }));
  }
}
