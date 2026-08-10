import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/attacks/boss_attack.dart';
import 'package:normaldo_gaming/game/components/item_components/shuriken.dart';
import 'package:normaldo_gaming/game/components/grid.dart';

enum Corners { topLeft, topRight, bottomLeft, bottomRight }

final class Corner {
  const Corner({
    required this.corner,
    required this.position,
  });

  final Corners corner;
  final Vector2 position;
}

final class ShurikenShowerAttack extends BossAttack with HasNgAudio {
  static const shurikensSfxPath = 'audio/sfx/shurikens.mp3';

  ShurikenShowerAttack({
    required this.speed,
    this.endDelay = 0.5,
  })  : _completed = false,
        _inProgress = false;

  final double speed;
  final double endDelay;
  final List<Corner> corners = [];

  bool _completed;
  bool _inProgress;

  @override
  bool get completed => _completed;

  @override
  bool get inProgress => _inProgress;

  @override
  void start(Boss boss, Grid grid) {
    _inProgress = true;
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
    corners.shuffle();
    _iterationAnimation(
      boss,
      grid,
      0,
    );
  }

  void _iterationAnimation(Boss boss, Grid grid, int cornerIndex) {
    const fadeInDuration = 0.3;
    boss.scale = Vector2.zero();
    final corner = corners[cornerIndex];
    final isFlippedHorizontally = boss.isFlippedHorizontally;
    if ((corner.corner == Corners.topLeft ||
            corner.corner == Corners.bottomLeft) &&
        !isFlippedHorizontally) {
      boss.flipHorizontallyAroundCenter();
    } else if ((corner.corner == Corners.topRight ||
            corner.corner == Corners.bottomRight) &&
        isFlippedHorizontally) {
      boss.flipHorizontallyAroundCenter();
    }
    boss.position = corner.position;
    boss.add(SequenceEffect([
      ScaleEffect.to(
          Vector2.all(1),
          EffectController(
            duration: fadeInDuration,
          ), onComplete: () {
        addShurikens(corner, boss, grid);
        audio.playAssetSfx(shurikensSfxPath);
      }),
      RotateEffect.by(
        pi * 2,
        EffectController(
          duration: 0.3,
        ),
      ),
      ScaleEffect.to(Vector2.zero(), EffectController(duration: fadeInDuration),
          onComplete: () {
        boss.add(TimerComponent(
            period: endDelay,
            removeOnFinish: true,
            onTick: () {
              _completed = true;
              _inProgress = false;
            }));
      }),
    ]));
  }

  void addShurikens(Corner corner, Boss boss, Grid grid) {
    var shurikens = <Shuriken>[];
    switch (corner.corner) {
      case Corners.topLeft:
        shurikens = [
          Shuriken()
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position = Vector2(boss.size.x * 2, boss.size.y - 30),
          Shuriken(startDelay: 0.2)
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position = Vector2(boss.size.x * 2, boss.size.y + 30),
          Shuriken(startDelay: 0.4)
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position = Vector2(boss.size.x, boss.size.y + 60)
        ];
      case Corners.topRight:
        shurikens = [
          Shuriken()
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position =
                Vector2(grid.size.x - boss.size.x * 2 - 20, boss.size.y - 30),
          Shuriken(startDelay: 0.2)
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position =
                Vector2(grid.size.x - boss.size.x * 2, boss.size.y + 35),
          Shuriken(startDelay: 0.4)
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position =
                Vector2(grid.size.x - boss.size.x - 30, boss.size.y * 2)
        ];
      case Corners.bottomRight:
        shurikens = [
          Shuriken()
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position = Vector2(
                grid.size.x - boss.size.x - 30, grid.size.y - boss.size.y * 2),
          Shuriken(startDelay: 0.2)
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position = Vector2(
                grid.size.x - boss.size.x * 2, grid.size.y - boss.size.y - 30),
          Shuriken(startDelay: 0.4)
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position = Vector2(
                grid.size.x - boss.size.x * 2, grid.size.y - boss.size.y / 2),
        ];
      case Corners.bottomLeft:
        shurikens = [
          Shuriken()
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position =
                Vector2(boss.size.x * 2 - 50, grid.size.y - boss.size.y * 2),
          Shuriken(startDelay: 0.2)
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position =
                Vector2(boss.size.x * 2, grid.size.y - boss.size.y - 30),
          Shuriken(startDelay: 0.4)
            ..speed = speed
            ..size = Items.shuriken.getSize(grid.lineSize)
            ..position =
                Vector2(boss.size.x * 2 + 15, grid.size.y - boss.size.y / 2)
        ];
      default:
        break;
    }
    boss.gameRef.grid.addAll(shurikens);
  }
}
