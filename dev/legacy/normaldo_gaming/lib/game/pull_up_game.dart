import 'dart:async';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/palette.dart';
import 'package:flutter/widgets.dart';
import 'package:normaldo_gaming/application/ads/ads_cubit.dart';
import 'package:normaldo_gaming/application/education/cubit/education_cubit.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/application/mission/mission_cubit.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/roller/roller.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/app/audio_pools.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level_manager.dart';
import 'package:normaldo_gaming/game/components/education/education_component.dart';
import 'package:normaldo_gaming/game/components/fat_counter.dart';
import 'package:normaldo_gaming/game/components/pause_button.dart';
import 'package:normaldo_gaming/game/utils/overlays.dart';
import 'package:normaldo_gaming/injection/injection.dart';

import 'components/components.dart';
import 'components/grid.dart';

final class Level {
  final Sprite bgSprite;
  final Map<int, Roller<Items>> itemsByLevel;
  final double speed;

  const Level({
    required this.bgSprite,
    required this.itemsByLevel,
    required this.speed,
  });

  bool contains(Items item) {
    return itemsByLevel.entries
        .any((element) => element.value.items.contains(item));
  }
}

class PullUpGame extends FlameGame
    with TapCallbacks, DragCallbacks, HasCollisionDetection, HasNgAudio {
  static final menuIconSize = Vector2.all(30);

  final UserCubit userCubit;
  final GameSessionCubit gameSessionCubit;
  final LevelBloc levelBloc;
  final MissionCubit missionCubit;
  final EducationCubit educationCubit;
  final AdsCubit adsCubit;

  PullUpGame({
    required this.userCubit,
    required this.gameSessionCubit,
    required this.levelBloc,
    required this.missionCubit,
    required this.educationCubit,
    required this.sfxPools,
    required this.adsCubit,
  });

  // Components
  late final Scene scene;
  final scoreLabel = ScoreLabel();
  final balance = Balance();
  final pauseButton = PauseButton();
  late final FatCounter fatCounter;
  late final Grid grid;
  late final List<Level> levels;

  final AudioPools sfxPools;

  final _levelManager = injector.get<LevelManager>();
  LevelManager get levelManager => _levelManager;

  bool bossInProgress = false;

  static const _allLevelItems = <(Items, double)>[
    (Items.magicHat, 0.2),
    (Items.energizer, 1.0),
    (Items.pizza, 50.0),
    (Items.moneyBag, 0.1),
    (Items.dollar, 2.0),
    (Items.hourglass, 0.5),
    (Items.caseyMask, 0.1),
    (Items.magnet, 2.0),
    (Items.boombox, 2.0),
    (Items.magicBox, 3.0),
    (Items.mutagen, 0.1),
    (Items.tv, 1),
  ];

  @override
  bool get debugMode => false;

  @override
  void onRemove() {
    missionCubit.resetOneGames();
    if (!gameSessionCubit.state.isDead) {
      missionCubit.resetAllProgress();
    }
    super.onRemove();
  }

  List<Items> currentLevelSlowMoItems() {
    final items = _itemsByLevel[levelBloc.state.level.index]?.items;
    if (items != null) {
      return items
          .where((e) =>
              e == Items.bananaPeel ||
              e == Items.beer ||
              e == Items.cocktail ||
              e == Items.girl ||
              e == Items.greenPoison ||
              e == Items.letterBottle)
          .toList();
    } else {
      return [];
    }
  }

  List<Items> currentLevelGuardItems() {
    final items = _itemsByLevel[levelBloc.state.level.index]?.items;
    if (items != null) {
      return items
          .where((e) =>
              e == Items.bird ||
              e == Items.bubbles ||
              e == Items.cone ||
              // e == Items.policeAlarm ||
              e == Items.snake ||
              e == Items.spadesCard ||
              e == Items.stone ||
              e == Items.tire ||
              e == Items.umbrella)
          .toList();
    } else {
      return [];
    }
  }

  List<Items> currentLevelPunchItems() {
    final items = _itemsByLevel[levelBloc.state.level.index]?.items;
    if (items != null) {
      return items
          .where((e) => e == Items.punch || e == Items.angryDog)
          .toList();
    } else {
      return [];
    }
  }

  final Map<int, Roller<Items>> _itemsByLevel = {
    0: Roller<Items>([
      ..._allLevelItems,
      (Items.bananaPeel, 80),
      (Items.trashBin, 3),
      (Items.policeCar, 20),
    ]),
    1: Roller<Items>([
      ..._allLevelItems,
      (Items.bananaPeel, 20),
      (Items.cone, 10),
      (Items.homeless, 10),
    ]),
    2: Roller<Items>([
      ..._allLevelItems,
      (Items.bananaPeel, 20),
      (Items.roadSign, 10),
      (Items.cone, 10),
      (Items.homeless, 5),
      (Items.trashBin, 3),
    ]),
    3: Roller<Items>([
      ..._allLevelItems,
      (Items.bananaPeel, 20),
      (Items.roadSign, 20),
      (Items.trashBin, 20),
      (Items.cone, 20),
      (Items.homeless, 20),
      (Items.punch, 20),
    ]),
    5: Roller<Items>([
      ..._allLevelItems,
      (Items.bananaPeel, 20),
      (Items.roadSign, 20),
      (Items.trashBin, 20),
      (Items.cone, 40),
      (Items.homeless, 20),
      (Items.punch, 20),
    ]),
    9: Roller<Items>([
      ..._allLevelItems,
      (Items.letterBottle, 20),
      (Items.compass, 20),
      (Items.tire, 20),
    ]),
    10: Roller<Items>([
      ..._allLevelItems,
      (Items.letterBottle, 20),
      (Items.compass, 20),
      (Items.umbrella, 20),
      (Items.cone, 20),
      (Items.tire, 20),
    ]),
    11: Roller<Items>([
      ..._allLevelItems,
      (Items.letterBottle, 20),
      (Items.compass, 20),
      (Items.umbrella, 20),
      (Items.cone, 20),
      (Items.shipPart, 40),
      (Items.bird, 20),
      (Items.tire, 20),
    ]),
    12: Roller<Items>([
      ..._allLevelItems,
      (Items.letterBottle, 20),
      (Items.compass, 20),
      (Items.umbrella, 20),
      (Items.cone, 20),
      (Items.shipPart, 40),
      (Items.bird, 20),
      (Items.homeless, 20),
      (Items.tire, 20),
    ]),
    13: Roller<Items>([
      ..._allLevelItems,
      (Items.letterBottle, 20),
      (Items.compass, 20),
      (Items.umbrella, 20),
      (Items.cone, 20),
      (Items.shipPart, 40),
      (Items.bird, 20),
      (Items.homeless, 20),
      (Items.punch, 20),
      (Items.tire, 20),
    ]),
    28: Roller<Items>([
      ..._allLevelItems,
      (Items.compass, 2),
      (Items.bananaPeel, 20),
      (Items.beer, 20),
    ]),
    31: Roller<Items>([
      ..._allLevelItems,
      (Items.umbrella, 20),
      (Items.compass, 2),
      (Items.bananaPeel, 20),
      (Items.beer, 20),
    ]),
    36: Roller<Items>([
      ..._allLevelItems,
      (Items.umbrella, 20),
      (Items.stone, 20),
      (Items.compass, 2),
      (Items.bananaPeel, 20),
      (Items.beer, 20),
    ]),
    44: Roller<Items>([
      ..._allLevelItems,
      (Items.umbrella, 20),
      (Items.stone, 20),
      (Items.compass, 2),
      (Items.bananaPeel, 20),
      (Items.beer, 20),
    ]),
    54: Roller<Items>([
      ..._allLevelItems,
      (Items.policeCar, 5),
      (Items.tire, 20),
      (Items.molotov, 2),
      (Items.angryDog, 20),
      (Items.trashBin, 5),
    ]),
    67: Roller<Items>([
      ..._allLevelItems,
      (Items.policeman, 5),
      (Items.cone, 20),
      (Items.handcuffs, 2),
      (Items.homeless, 20),
      (Items.girl, 5),
      (Items.tire, 20),
    ]),
  };

  @override
  Future<void> onLoad() async {
    final level1 = await Sprite.load('backgrounds/level1.png');
    final level2 = await Sprite.load('backgrounds/level2.png');
    final level3 = await Sprite.load('backgrounds/LEVEL 3.png');
    final level4 = await Sprite.load('backgrounds/LEVEL 4.png');
    final level5 = await Sprite.load('backgrounds/LEVEL 5.png');
    levels = [
      Level(
        bgSprite: level1,
        itemsByLevel: _itemsByLevel,
        speed: 100,
      ),
      Level(
        bgSprite: level2,
        itemsByLevel: _itemsByLevel,
        speed: 100,
      ),
      Level(
        bgSprite: level3,
        itemsByLevel: _itemsByLevel,
        speed: 100,
      ),
      Level(
        bgSprite: level4,
        itemsByLevel: _itemsByLevel,
        speed: 100,
      ),
      Level(
        bgSprite: level5,
        itemsByLevel: _itemsByLevel,
        speed: 100,
      ),
    ];
    camera.moveTo(size / 2);
    add(TimerComponent(
      period: 1,
      removeOnFinish: true,
      onTick: () {},
    ));
    fatCounter = FatCounter(skin: userCubit.state.skin);
    _initializeComponents();

    await _initBloc();

    // camera.viewfinder.zoom = 0.4;

    if (!userCubit.state.educated) {
      add(TimerComponent(
        period: 0.5,
        removeOnFinish: true,
        onTick: () {
          pauseButton.position -= Vector2(0, 200);
          add(EducationComponent());
        },
      ));
    }

    sfxPools
        .init(userCubit.state.skin)
        .whenComplete(() => print('AUDIO POOLS SUCCESSFULLY LOADED'));

    overlays.add(Overlays.missions.name);

    return super.onLoad();
  }

  void _initializeComponents() {
    scene = Scene(
      levels,
      initialSize: Vector2(size.x, size.x),
    );
    scene.size = size;
    balance.position =
        Vector2(scoreLabel.x, scoreLabel.y + scoreLabel.size.y + 8);
    fatCounter.position.x = scoreLabel.x + 8;
    fatCounter.position.y = balance.position.y + balance.size.y + 16;
    fatCounter.size = Vector2(90, menuIconSize.y);
  }

  Future<void> _initBloc() async {
    gameSessionCubit.stream.listen((state) async {
      if (state.paused) {
        audio.pauseAssetBgm();
      }
      if (state.isDead) {
        await audio.pauseAssetBgm();
        pauseEngine();
        overlays.add(Overlays.deathScreen.name);
      } else {
        if (!state.paused && (state.revived || state.revivedWithAd)) {
          overlays.remove(Overlays.deathScreen.name);
          await audio.resumeAssetBgm();
          resumeEngine();
        }
      }
    });

    await camera.viewfinder.add(FlameBlocProvider<LevelBloc, LevelState>.value(
        value: levelBloc,
        children: [
          scene,
          grid = Grid(
            skin: userCubit.state.skin,
            gameSessionCubit: gameSessionCubit,
            levelBloc: levelBloc,
          )
            ..size = Vector2(size.x, size.y)
            ..position = Vector2(0, 0),
        ]));
    await camera.viewfinder.add(
      FlameBlocProvider<GameSessionCubit, GameSessionState>.value(
        value: gameSessionCubit,
        children: [
          RectangleComponent(
              size: Vector2(150, 100),
              paint: Paint()
                ..color = BasicPalette.black.color.withOpacity(0.5)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100)),
          scoreLabel,
          fatCounter,
          balance,
          pauseButton..position = Vector2(size.x - pauseButton.size.x - 32, 0),
        ],
      ),
    );
  }
}
