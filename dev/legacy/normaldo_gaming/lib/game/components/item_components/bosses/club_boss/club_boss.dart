import 'dart:async';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:flame/flame.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';

import 'package:normaldo_gaming/game/components/effects/effects.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss_calls_girls.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss_calls_police.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss_calls_security.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss_finishing.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss_knuckles.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/club_boss/club_boss_track.dart';
import 'package:normaldo_gaming/game/components/item_components/security.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

// bomb white screen animation
// some figures appear particularly on screen
// audio with preloaded audio players
// more items, less speed
// club boss finishing animation

enum ClubBossState {
  idle,
  callSecurity,
  callPolice,
  callGirls,
  track,
}

final class ClubBoss extends SpriteAnimationGroupComponent<ClubBossState>
    with HasGameRef<PullUpGame>, CollisionCallbacks, Boss, Effects {
  ClubBoss() {
    debugMode = false;
  }

  late final Sprite phoneSprite;
  late final Sprite knuckleSprite;

  bool tracking = false;

  @override
  List<Items> get immuneToItems => [Items.security, Items.girl];

  Future<void> callSecurity({void Function()? onComplete}) async {
    current = ClubBossState.callSecurity;
    takePhone(onComplete: () {
      add(MoveByEffect(
        Vector2(size.x * 2, 0),
        EffectController(duration: 1),
        onComplete: onComplete,
      ));
    });
  }

  void knucklesUp() {
    add(ClubBossKnuckles());
  }

  void knucklesDown() {
    children.whereType<ClubBossKnuckles>().forEach((element) {
      element.knucklesDown();
    });
  }

  void takePhone({void Function()? onComplete}) {
    final moveEffectVector = Vector2(5, 5);
    add(SpriteComponent(
      sprite: phoneSprite,
      size: size / 2,
      priority: 0,
      anchor: Anchor.center,
      scale: Vector2.all(0.1),
      position: size / 2,
    )..add(SequenceEffect([
        ScaleEffect.to(
          Vector2.all(1),
          EffectController(duration: 0.1),
        ),
        MoveByEffect(
            moveEffectVector,
            EffectController(
              duration: 0.5,
            ), onComplete: () {
          gameRef.audio.playAssetSfx('audio/bosses/nigga_boss/TALK.mp3');
          _callSecurityWave();
        }),
        RotateEffect.by(
          0.05,
          EffectController(
            duration: 0.2,
            repeatCount: 5,
          ),
        ),
        MoveByEffect(
          -moveEffectVector,
          EffectController(
            duration: 0.5,
          ),
        ),
        ScaleEffect.to(
          Vector2.all(0.1),
          EffectController(duration: 0.1),
        ),
        RemoveEffect(onComplete: onComplete),
      ])));
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
        gameRef.audio.playAssetSfx('audio/bosses/nigga_boss/WHOS NEXT.mp3');

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
        }));
      })
    ]);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (tracking) {
      angleTo(gameRef.grid.normaldo.position);
      position.moveToTarget(gameRef.grid.normaldo.position, 100 * dt);
      _flipIfNeeded();
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
  set current(ClubBossState? value) {
    switch (value) {
      case ClubBossState.idle:
        break;
      case ClubBossState.callSecurity:
        add(RotateEffect.by(
          0.02,
          EffectController(
            startDelay: 1,
            duration: 0.2,
            repeatCount: 8,
            reverseDuration: 0.2,
          ),
          onComplete: () {},
        ));
      // add(TimerComponent(
      //     period: 1,
      //     removeOnFinish: true,
      //     onTick: () {
      //       current = ClubBossState.idle;
      //     }));
      // size =
      // Vector2(game.grid.lineSize * 1.5, game.grid.lineSize * 1.5 * 1.99);
      default:
        break;
    }
    children.whereType<RectangleHitbox>().forEach((element) {
      element.size = size * 0.9;
    });
    super.current = value;
  }

  @override
  FutureOr<void> onLoad() async {
    phoneSprite = await Sprite.load('bosses/club_boss_phone.png');
    knuckleSprite = await Sprite.load('bosses/club_boss_knuckle.png');
    final idleSprite1 = await Sprite.load('bosses/club_boss1.png');
    final idleSprite2 = await Sprite.load('bosses/club_boss2.png');
    final loserTicketSprite =
        await Sprite.load('bosses/club_boss_loser_ticket.png');
    final callAnimation = SpriteAnimation.fromFrameData(
      await Flame.images.load('bosses/club_boss_talk.png'),
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.2,
        textureSize: Vector2(500, 500),
        loop: false,
      ),
    );
    final callPoliceAnimation = SpriteAnimation.fromFrameData(
      await Flame.images.load('bosses/club_boss_rage_talk.png'),
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.1,
        textureSize: Vector2(500, 500),
        loop: true,
      ),
    );
    final callGirlsAnimation = SpriteAnimation.spriteList(
      [loserTicketSprite],
      stepTime: 5,
    );

    animations = {
      ClubBossState.idle: SpriteAnimation.spriteList(
        [idleSprite1, idleSprite2],
        stepTime: 5,
      ),
      ClubBossState.callSecurity: callAnimation,
      ClubBossState.callPolice: callPoliceAnimation,
      ClubBossState.callGirls: callGirlsAnimation,
      ClubBossState.track: callPoliceAnimation,
    };
    current = ClubBossState.idle;
    add(CircleHitbox.relative(
      0.3,
      parentSize: size,
      anchor: anchor,
      position: center,
    ));
    const double endDelay = 3;
    attacks = [
      ClubBossCallsSecurity(),
      ClubBossCallsSecurity(endDelay: endDelay),
      ClubBossCallsPolice(),
      ClubBossCallsSecurity(),
      ClubBossCallsSecurity(endDelay: endDelay),
      ClubBossCallsPolice(),
      ClubBossCallsGirls(),
      ClubBossTrack(),
      ClubBossFinishing(),
    ];
    return super.onLoad();
  }

  void _callSecurityWave() {
    const double speed = 250;
    final grid = gameRef.grid;
    final yIndexes = [0, 1, 2, 3, 4];
    grid.addAll([
      Security()
        ..speed = speed
        ..anchor = Anchor.center
        ..size = Items.security.getSize(grid.lineSize)
        ..position = Vector2(
            grid.size.x + size.x * 1, grid.linesCentersY[yIndexes.random()]),
      Security()
        ..speed = speed
        ..anchor = Anchor.center
        ..size = Items.security.getSize(grid.lineSize)
        ..position = Vector2(
            grid.size.x + size.x * 3, grid.linesCentersY[yIndexes.random()]),
      Security()
        ..speed = speed
        ..anchor = Anchor.center
        ..size = Items.security.getSize(grid.lineSize)
        ..position = Vector2(
            grid.size.x + size.x * 5, grid.linesCentersY[yIndexes.random()]),
      Security()
        ..speed = speed
        ..anchor = Anchor.center
        ..size = Items.security.getSize(grid.lineSize)
        ..position = Vector2(
            grid.size.x + size.x * 7, grid.linesCentersY[yIndexes.random()]),
      Security()
        ..speed = speed
        ..anchor = Anchor.center
        ..size = Items.security.getSize(grid.lineSize)
        ..position = Vector2(
            grid.size.x + size.x * 9, grid.linesCentersY[yIndexes.random()]),
    ]);
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
}
