import 'dart:async';
import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:flame/flame.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';

import 'package:normaldo_gaming/game/components/effects/effects.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/leatherhead/leatherhead_buckshot.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/leatherhead/leatherhead_hunting.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/leatherhead/leatherhead_tail_attack.dart';
import 'package:normaldo_gaming/game/components/item_components/bullet.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

/*

ВЫСТРЕЛЫ
  1. Прицельный выстрел (одна пуля быстро пролетает по направлению куда смотрит крок)
  2. Картечь (вылетает 3 пули средняя скорость. Крайние пули летят наискось, средняя прямо)
  3. Злая картечь (Крок открывает пасть, разъяренно стреляет 2 раза картечью)
АТАКИ
  1. ХАНТ
    1. Вылезает из края экрана с пушкой внизу.
    2. Прицеливается и смотрит за игроком.
    3. Перезаряжает пушку вверху (sniperShoot)
    4. Прицельный выстрел. (sniperShoot)
    5. Возвращается к спрайту где пушка внизу. 

    1.2 ВЫСТРЕЛ КАРТЕЧЬЮ
      1. Вылезает из края с пушкой внизу
      2.  Перезаряжает пушку внизу и стреляет. (картечь анимация (перезарядка внизу + выстрел))
      4. Возвращается к спрайту где пушка внизу. 
      5. Злится и делает три вытсрела картечью подряд.

  2. РАЗДУВ
    1. Вылезает обычный спрайт крока из-за экрана.
    2. Начинает трястись, глаза красные, увеличивается (макс. все линии).
    3. Показываем подсказку с пальцем (animation) и можно тапать по боссу. Каждый тап
немного уменьшает босса, не давая ему раздуться на весь экран. Также каждый тап 
выкидывает пиццу(~0.9) или далары(~0.99), мешок денег (~0.01) из босса.
    4. Крок раздувается 5 сек. после чего уходит за экран так, чтобы торчал нос.
    5. Крок ездит вверх-вниз, фиксируется на рандомной высоте, открывает пасть и резко пролетает
по линии до начала экрана, меняется на спрайт с захлопнутой челюстью и откатывается назад за экран.

  3. УДАР ХВОСТОМ
    1. Хвост медленно вылезает из края экрана и бьет влево-вправо
    2. Хвост со средней скоростью делает пролет от края до края. лево-право. 
право-лево. вверх-вниз. вниз-вверх.

  4. ИСЧЕЗНОВЕНИЕ
    КРок вылезает, ему на лицо падает пицца, он смотрит влево-вправо, большой хвост
    пролетает через экран, сносит крока.
 */

enum LeatherheadState {
  idle,
  squint,
  takeGun,
  hunt,
  aim,
  shoot,
  reload1,
  reloadUp,
  buckshot,
  crazyBuckshot,
  sniperShot,
}

final class Leatherhead extends SpriteAnimationGroupComponent<LeatherheadState>
    with HasGameRef<PullUpGame>, CollisionCallbacks, Boss, Effects {
  static const buckshotStepTime = 0.15;

  Leatherhead() {
    debugMode = false;
  }

  var _hunting = false;

  Grid get grid => gameRef.grid;

  @override
  List<Items> get immuneToItems => [Items.bullet];

  void hunt({void Function()? onComplete}) {
    final key = ComponentKey.unique();
    current = LeatherheadState.aim;
    add(AnchorByEffect(Vector2(0.3, 0), EffectController(duration: 0.05),
        onComplete: () {
      _hunting = true;
      add(TimerComponent(
          period: 2,
          repeat: true,
          removeOnFinish: true,
          key: key,
          onTick: () {
            current = LeatherheadState.reloadUp;
            gameRef.audio.playAssetSfx('audio/bosses/leatherhead/reload.mp3');

            animationTicker?.onComplete = () {
              current = LeatherheadState.sniperShot;
              final nPosition = grid.normaldo.position;
              final distinction = nPosition - position;
              final destination = nPosition + (distinction * 3);
              angle = angleTo(grid.normaldo.position) + (pi / 2);
              animationTicker?.onFrame = (frame) {
                if (frame == 1) {
                  gameRef.audio
                      .playAssetSfx('audio/bosses/leatherhead/SNIPER.mp3');
                  grid.add(Bullet(destination: destination)
                    ..priority = 1
                    ..size = Items.bullet.getSize(grid.lineSize)
                    ..position = position - Vector2(size.x / 2, 0));
                }
              };
              animationTicker?.onComplete = () {
                current = LeatherheadState.aim;
              };
            };
          }));
      add(TimerComponent(
          period: 10,
          removeOnFinish: true,
          onTick: () {
            gameRef.findByKey<TimerComponent>(key)?.timer.stop();
            current = LeatherheadState.takeGun;
            _hunting = false;
            lookAt(gameRef.grid.center);
            onComplete?.call();
          }));
    }));
  }

  void buckshot({void Function()? onComplete}) {
    final key = ComponentKey.unique();
    _hunting = true;
    add(TimerComponent(
        period: buckshotStepTime * 5,
        repeat: true,
        removeOnFinish: true,
        key: key,
        onTick: () {
          current = LeatherheadState.buckshot;
          animationTicker?.onFrame = (frame) {
            const double bulletSpeed = 600;
            final bulletSize = Items.bullet.getSize(grid.lineSize);

            final midPosition = grid.normaldo.position;
            final topPosition = midPosition - Vector2(0, 100);
            final bottomPosition = midPosition + Vector2(0, 100);

            final midDistinction = midPosition - position;
            final topDistinction = topPosition - position;
            final bottomDistinction = bottomPosition - position;

            final midDestination = midPosition + (midDistinction * 3);
            final topDestination = topPosition + (topDistinction * 3);
            final bottomDestination = bottomPosition + (bottomDistinction * 3);

            if (frame == 0) {
              gameRef.audio.playAssetSfx('audio/bosses/leatherhead/reload.mp3');
            }

            if (frame == 3) {
              gameRef.audio
                  .playAssetSfx('audio/bosses/leatherhead/DROBASH.mp3');
              grid.add(Bullet(
                destination: topDestination,
                animationSpeed: bulletSpeed,
              )
                ..priority = 1
                ..size = bulletSize
                ..position =
                    position - Vector2(size.x / 2, bulletSize.y * 1.5));
              grid.add(Bullet(
                destination: midDestination,
                animationSpeed: bulletSpeed,
              )
                ..priority = 1
                ..size = bulletSize
                ..position = position - Vector2(size.x / 2, 0));
              grid.add(Bullet(
                destination: bottomDestination,
                animationSpeed: bulletSpeed,
              )
                ..priority = 1
                ..size = bulletSize
                ..position =
                    position - Vector2(size.x / 2, -bulletSize.y * 1.5));
            }
          };
          animationTicker?.onComplete = () {
            current = LeatherheadState.takeGun;
          };
        }));
    add(TimerComponent(
        period: 10,
        removeOnFinish: true,
        onTick: () {
          gameRef.findByKey<TimerComponent>(key)?.timer.stop();
          current = LeatherheadState.takeGun;
          _hunting = false;
          lookAt(gameRef.grid.center);
          onComplete?.call();
        }));
  }

  @override
  void start() {
    gameRef.grid.stopAllLines();
    game.grid.removeAllItems();
    const double moveFromRightSideDur = 1;
    final grid = game.grid;
    scale = Vector2.all(4);
    // Move boss from outside of screen to the right side
    addAll([
      MoveEffect.to(
          Vector2(grid.size.x - size.x / 2, grid.size.y / 2),
          EffectController(
            duration: moveFromRightSideDur,
          ), onComplete: () {
        // Normaldo takes his position when boss talking
        gameRef.audio
            .playAssetSfx('audio/bosses/leatherhead/RAAW LITTLE TURLE.mp3');
        if (grid.normaldo.position != grid.center) {
          grid.normaldo.addAll(jumpToEffect(
            position: grid.center,
          ));
        }
      }),
      // Boss shaking when moving and camera zooming in
      RotateEffect.by(
          0.05,
          EffectController(
            repeatCount: moveFromRightSideDur.toInt(),
            duration: 1,
            reverseDuration: 1,
          ), onComplete: () {
        // Boss shaking his head when talking
        add(RotateEffect.by(
            0.05,
            EffectController(
              repeatCount: 1,
              duration: 0.4,
              reverseDuration: 1,
            ), onComplete: () {
          // boss warning
          warn();
          // boss moving backwards
          add(MoveByEffect(
            Vector2(size.x * 3, 0),
            EffectController(duration: moveFromRightSideDur),
          ));
          game.camera.moveTo(game.size / 2, speed: 500);
        }));
      })
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_hunting) {
      lookAt(gameRef.grid.normaldo.position);
    }

    if (bossWarned) {
      // if (opacity == 0) {
      //   opacity = 1;
      // }
      if (attacks.isNotEmpty) {
        if (attacks.first.completed) {
          attacks.removeAt(0);
          if (attacks.isNotEmpty) {
            attacks.first.start(this, gameRef.grid);
          }
        } else if (!attacks.first.inProgress) {
          attacks.first.start(this, gameRef.grid);
        }
      } else {
        gameRef.bossInProgress = false;
        gameRef.levelBloc.add(LevelEvent.startFigure(
            figure: FigureEvent.winLabel(
          item: [Items.pizza, Items.dollar].random(),
        )));
        removeFromParent();
        gameRef.scene.moveToNextLevel();
      }
    }
  }

  @override
  FutureOr<void> onLoad() async {
    const double stepTime = 0.3;
    // game.camera.viewfinder.add(ScaleEffect.to(
    //     Vector2.all(0.5),
    //     EffectController(
    //       duration: 0.1,
    //     )));
    nativeAngle = -pi / 2;
    priority = 2;
    final idleSprite = await Sprite.load('bosses/leatherhead_idle.png');
    final squintSprite = await Sprite.load('bosses/leatherhead_squint.png');
    final takeGunSprite = await Sprite.load('bosses/leatherhead_gun.png');
    final aimingSprite = await Sprite.load('bosses/leatherhead_aiming.png');
    final shotSprite = await Sprite.load('bosses/leatherhead_shot.png');
    final afterShotSprite =
        await Sprite.load('bosses/leatherhead_after_shot.png');

    final huntAnimation = SpriteAnimation.fromFrameData(
      await Flame.images.load('bosses/leatherhead_hunt.png'),
      SpriteAnimationData.sequenced(
        amount: 21,
        stepTime: stepTime,
        textureSize: Vector2(1000, 1000),
        loop: false,
      ),
    );
    final reloadUpAnimation = SpriteAnimation.fromFrameData(
      await Flame.images.load('bosses/reload up.png'),
      SpriteAnimationData.sequenced(
        amount: 3,
        stepTime: stepTime,
        textureSize: Vector2(1000, 1000),
        loop: false,
      ),
    );
    final reload1Animation = SpriteAnimation.fromFrameData(
      await Flame.images.load('bosses/leatherhead_reload1.png'),
      SpriteAnimationData.sequenced(
        amount: 3,
        stepTime: stepTime,
        textureSize: Vector2(1000, 1000),
        loop: false,
      ),
    );
    final crazyBuckshotAnimation = SpriteAnimation.fromFrameData(
      await Flame.images.load('bosses/kartech.png'),
      SpriteAnimationData.sequenced(
        amount: 7,
        stepTime: 0.15,
        textureSize: Vector2(1000, 1000),
        loop: false,
      ),
    );
    final buckshotAnimation = SpriteAnimation.fromFrameData(
      await Flame.images.load('bosses/shotdown.png'),
      SpriteAnimationData.sequenced(
        amount: 5,
        stepTime: buckshotStepTime,
        textureSize: Vector2(1000, 1000),
        loop: false,
      ),
    );
    final sniperShotAnimation = SpriteAnimation.fromFrameData(
      await Flame.images.load('bosses/sniper shot.png'),
      SpriteAnimationData.sequenced(
        amount: 3,
        stepTime: stepTime,
        textureSize: Vector2(1000, 1000),
        loop: false,
      ),
    );

    animations = {
      LeatherheadState.idle: SpriteAnimation.spriteList(
        [idleSprite, idleSprite],
        stepTime: 5,
      ),
      LeatherheadState.squint: SpriteAnimation.spriteList(
        [squintSprite, squintSprite],
        stepTime: 5,
      ),
      LeatherheadState.takeGun: SpriteAnimation.spriteList(
        [takeGunSprite, takeGunSprite],
        stepTime: 5,
      ),
      LeatherheadState.aim: SpriteAnimation.spriteList(
        [aimingSprite, aimingSprite],
        stepTime: 5,
      ),
      LeatherheadState.reload1: reload1Animation,
      LeatherheadState.buckshot: buckshotAnimation,
      LeatherheadState.crazyBuckshot: crazyBuckshotAnimation,
      LeatherheadState.reloadUp: reloadUpAnimation,
      LeatherheadState.sniperShot: sniperShotAnimation,
      LeatherheadState.shoot: SpriteAnimation.variableSpriteList(
        [
          shotSprite,
          afterShotSprite,
          takeGunSprite,
        ],
        stepTimes: [
          0.3,
          0.5,
          0.2,
        ],
        loop: false,
      ),
      LeatherheadState.hunt: huntAnimation,
    };
    current = LeatherheadState.idle;
    add(CircleHitbox.relative(
      0.3,
      parentSize: size,
      anchor: anchor,
      position: center,
    ));
    attacks = [
      LeatherheadHunting(),
      LeatherheadTailAttack(side: TailSide.bottom, speed: 200),
      LeatherheadTailAttack(side: TailSide.top, speed: 300),
      LeatherheadTailAttack(side: TailSide.bottom, speed: 400),
      LeatherheadTailAttack(side: TailSide.top, speed: 400),
      LeatherheadBuckshot(),
      LeatherheadTailAttack(side: TailSide.bottom, speed: 300),
      LeatherheadTailAttack(side: TailSide.top, speed: 400),
      LeatherheadTailAttack(side: TailSide.bottom, speed: 500),
      LeatherheadTailAttack(side: TailSide.top, speed: 600),
      LeatherheadBuckshot(),
    ];
    return super.onLoad();
  }

  void _flipIfNeeded() {
    final normaldo = gameRef.grid.normaldo;
    if (center.x > normaldo.center.x && isFlippedHorizontally) {
      flipHorizontallyAroundCenter();
    }
    if (center.x < normaldo.center.x && !isFlippedHorizontally) {
      flipHorizontallyAroundCenter();
    }
  }

  @override
  set current(LeatherheadState? value) {
    final height = gameRef.grid.lineSize;
    switch (value) {
      case LeatherheadState.aim:
        final y = height * 0.7;
        size = Vector2(y * 1.83, y);
      case LeatherheadState.reloadUp:
      case LeatherheadState.sniperShot:
        size = Vector2.all(gameRef.grid.lineSize) * 1.1;
      case LeatherheadState.shoot:
        final y = height;
        size = Vector2(y * 1.83, y);
      default:
        anchor = Anchor.center;
        size = Vector2.all(gameRef.grid.lineSize);
    }
    super.current = value;
  }
}
