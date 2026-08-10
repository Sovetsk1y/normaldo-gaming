import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/widgets.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/ninja_foot/ninja_foot.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/shuriken_shower_attack.dart';
import 'boss_attack.dart';

final class PredatorAttack extends BossAttack with HasNgAudio {
  static const predatorSfxPath = 'audio/sfx/shredder_predator.mp3';

  PredatorAttack({
    required this.speed,
  })  : _completed = false,
        _inProgress = false;

  final double speed;

  bool _completed;
  bool _inProgress;

  @override
  bool get completed => _completed;

  @override
  bool get inProgress => _inProgress;

  final corners = <Corner>[];

  SpriteAnimationGroupComponent<NinjaFootState> bossComp(Boss boss) =>
      boss as SpriteAnimationGroupComponent<NinjaFootState>;

  @override
  void start(Boss boss, Grid grid) {
    _inProgress = true;
    if (corners.isEmpty) {
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
    }
    corners.shuffle();
    boss.scale = Vector2.all(0);
    boss.position = corners.removeAt(0).position;
    boss.scale = Vector2.all(1);
    flipIfNeeded(boss, grid.normaldo);
    final nPosition = grid.normaldo.position;
    final distinction = nPosition - boss.position;
    var destination = nPosition + distinction;
    while (destination.y > 0 && destination.y < grid.size.y) {
      destination += distinction;
    }
    if (destination.y > grid.size.y + boss.size.y) {
      destination.y = grid.size.y + boss.size.y;
    }
    if (destination.y < -boss.size.y) {
      destination.y = -boss.size.y;
    }
    if (destination.x > grid.size.x + boss.size.x) {
      destination.x = grid.size.x + boss.size.x;
    }
    if (destination.x < -boss.size.x) {
      destination.x = -boss.size.x;
    }
    audio.playAssetSfx(predatorSfxPath);
    final predator = ([
      NinjaFootState.predator1,
      NinjaFootState.predator2,
      NinjaFootState.predator3,
    ]..shuffle())
        .removeAt(0);
    bossComp(boss).current = predator;
    bossComp(boss).lookAt(grid.normaldo.position);
    boss.add(SizeEffect.to(
      boss.size * 1.6,
      EffectController(
        duration: 0.3,
        startDelay: 0.5,
        reverseDuration: 0.3,
      ),
    ));
    boss.add(
      MoveToEffect(
          destination,
          EffectController(
            speed: speed,
            curve: Curves.linear,
          ), onComplete: () {
        boss.angle = 0;
        _completed = true;
        _inProgress = false;
        bossComp(boss).current = NinjaFootState.idle;
      }),
    );
  }
}
