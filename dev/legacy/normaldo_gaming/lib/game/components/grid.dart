import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/skins/skins_repository.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/figure_event_component.dart';
import 'package:normaldo_gaming/game/components/level_timer_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

import 'normaldo.dart';

enum ComicsType {
  hurt,
  resist,
}

class Grid extends PositionComponent
    with
        DragCallbacks,
        HasGameRef<PullUpGame>,
        FlameBlocReader<LevelBloc, LevelState>,
        FlameBlocListenable<LevelBloc, LevelState>,
        HasNgAudio {
  Grid({
    required this.gameSessionCubit,
    required this.levelBloc,
    required this.skin,
  });

  final Skin skin;
  final GameSessionCubit gameSessionCubit;
  final LevelBloc levelBloc;

  late final Normaldo normaldo;

  double _lineSize = 0;
  double get lineSize => _lineSize;

  Map<int, double> _stoppedLines = {};
  List<double> _linesCentersY = [];
  List<double> get linesCentersY => _linesCentersY;

  bool _controlInverted = false;
  bool controlTurnedOff = false;

  List<double> lineXAllocation(double xSize) {
    const padding = 1.2;
    final width = xSize * padding;
    return List.generate(size.x ~/ width,
        (index) => (((size.x) / 8 * (index + 1))) + (width / 2));
  }

  TimerComponent? _itemsCreator;

  @override
  bool listenWhen(LevelState previousState, LevelState newState) {
    return previousState.level != newState.level ||
        previousState.miniGame != newState.miniGame;
  }

  bool gameInProgress = false;

  @override
  void onNewState(LevelState state) async {
    if (gameInProgress) gameInProgress = false;
    gameSessionCubit.changeLevel(state.level.index);
    if (_itemsCreator != null) remove(_itemsCreator!);
    _itemsCreator = TimerComponent(
      period: state.level.frequency,
      repeat: true,
      onTick: () {
        onItemsCreatorTick(state);
      },
    );
    if (state.figure != null) _itemsCreator?.timer.pause();
    add(_itemsCreator!);
  }

  Future<void> showCollisionComics({
    required ComicsType type,
    required Vector2 position,
    required Vector2 size,
  }) async {
    final path = switch (type) {
      ComicsType.hurt => [
          'ahh.png',
          'boom.png',
          'dang.png',
        ],
      ComicsType.resist => [
          skin.uniqueId == 'tyson' ? 'normaldo/tyson/punch.png' : 'knukl 1.png',
          'slakebake2 1.png',
        ]
    };
    final sprite = await Sprite.load(path.random());
    add(
      SpriteComponent(
        sprite: sprite,
        size: size,
        // size: Vector2(100, 80),
        // position: Vector2(grid.normaldo.size.x * 1.5, grid.normaldo.size.y / 2),
        position: position,
        priority: 0,
        anchor: Anchor.center,
        scale: Vector2.all(0),
      )..addAll([
          ScaleEffect.to(
            Vector2.all(1.2),
            EffectController(
              duration: 0.1,
            ),
          ),
          SequenceEffect([
            OpacityEffect.fadeOut(
              DelayedEffectController(EffectController(duration: 0.3),
                  delay: 0.1),
            ),
            RemoveEffect(),
          ])
        ]),
    );
  }

  void onItemsCreatorTick(LevelState state) {
    if (!gameRef.userCubit.state.educated) return;
    if (state.figure != null) return;
    if (gameRef.bossInProgress) return;
    final lineItem = gameRef.scene.currentLevel.itemsByLevel.entries
        .lastWhere((element) => element.key <= state.level.index,
            orElse: () => gameRef.scene.currentLevel.itemsByLevel.entries.last)
        .value
        .roll();
    final component = lineItem.component();
    component.size = lineItem.getSize(lineSize);
    final items = children.whereType<Item>();
    if (items.isNotEmpty) {
      if (items.last.position.x > gameRef.size.x * 1.5) return;
    }
    double lastItemPositionX = gameRef.size.x;
    double lastItemSizeX = 0;
    if (items.isNotEmpty) {
      if (items.last.position.x > gameRef.size.x) {
        lastItemPositionX = items.last.position.x;
      }
      lastItemSizeX = items.last.size.x;
    }
    component.position = Vector2(
        lastItemPositionX + lastItemSizeX + component.size.x,
        _linesCentersY[Random().nextInt(_linesCentersY.length)]);
    if (_stoppedLines.values.contains(component.position.y)) {
      return;
    }

    add(component);
  }

  void stopAllLines() {
    for (int i = 0; i < _linesCentersY.length; i++) {
      stopLine(i);
    }
  }

  void stopLine(int index) {
    assert(index >= 0 && index < 5, 'Your index – $index');
    if (_stoppedLines.keys.contains(index)) return;
    _stoppedLines[index] = _linesCentersY[index];
  }

  void resumeLines() {
    final toRemove = <int>[];
    for (final entry in _stoppedLines.entries) {
      toRemove.add(entry.key);
    }
    for (final key in toRemove) {
      _stoppedLines.remove(key);
    }
  }

  void removeAllItems({List<Component> exclude = const []}) {
    removeWhere(
      (component) {
        if (component is FigureEventComponent &&
            exclude.any((element) => component.contains(element))) {
          for (final exclusion in exclude) {
            for (final child in component.children) {
              if (child != exclusion) child.removeFromParent();
            }
          }
          return false;
        }
        return ((component is FigureEventComponent || component is Item) &&
            !exclude.contains(component));
      },
    );
  }

  void vanishRandomItem() {
    final items = children
        .whereType<Item>()
        .where((element) =>
            (element is AttackingItem ||
                element is KillingItem ||
                element is SlowingItem) &&
            element.position.x < size.x)
        .toList();
    if (items.isEmpty) return;
    final item = items.random();
    item.add(SequenceEffect([
      ScaleEffect.to(
        Vector2.all(1.1),
        EffectController(
          duration: 0.2,
        ),
      ),
      ScaleEffect.to(
        Vector2.all(0),
        EffectController(
          duration: 0.1,
        ),
      ),
    ], onComplete: () {
      item.removeFromParent();
    }));
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(gameRef.size.x, gameRef.size.y);
    _lineSize = size.y / Utils.linesCount;
    normaldo =
        Normaldo(size: Utils.normaldoSizeFromSkin(skin, lineSize), skin: skin)
          ..position = Vector2(size.x / 2, size.y / 2);
    for (int i = 0; i < Utils.linesCount; i++) {
      final lineCenterY = lineSize * i + lineSize / 2;
      _linesCentersY.add(lineCenterY);
      // gameRef.camera.viewfinder.zoom = 0.4;

      // 4DEV
      // line bounds highlights
      // add(RectangleComponent(
      //   position: Vector2(0, (i + 1) * lineSize),
      //   size: Vector2(size.x, 1),
      //   paint: Paint()..color = BasicPalette.yellow.color,
      // ));
      // // centers highlights
      // add(RectangleComponent(
      //   position: Vector2(0, lineCenterY),
      //   size: Vector2(size.x, 0.5),
      //   paint: Paint()..color = BasicPalette.green.color,
      // ));
    }
    // add(
    //   TrashBin()
    //     ..position = Vector2(size.x / 2, _linesCentersY[2])
    //     ..size = Items.trashBin.getSize(lineSize)
    //     ..moving = false,
    // );
    _itemsCreator = TimerComponent(
        period: levelBloc.state.level.frequency,
        repeat: true,
        onTick: () {
          onItemsCreatorTick(levelBloc.state);
        });
    add(_itemsCreator!);
    await add(FlameBlocProvider<GameSessionCubit, GameSessionState>.value(
        value: gameSessionCubit,
        children: [
          normaldo,
        ]));
    await add(FlameBlocListener<LevelBloc, LevelState>(
      listenWhen: (previousState, newState) =>
          previousState.figure != newState.figure,
      onNewState: (state) async {
        if (state.figure != null) {
          stopAllLines();
          children
              .where((e) => e is Item && e.position.x > size.x + 100)
              .forEach((element) {
            element.removeFromParent();
          });
          add(
            FigureEventComponent(
              figure: state.figure!,
              lineSize: lineSize,
              linesCentersY: linesCentersY,
              onFinish: () {
                bloc.add(const LevelEvent.finishFigure());
                gameRef.grid.resumeLines();
              },
            )
              ..position = Vector2(0, 0)
              ..size = size,
          );
        } else {
          onNewState(state);
        }
      },
    ));
    await add(FlameBlocProvider<LevelBloc, LevelState>.value(
        value: levelBloc,
        children: [
          LevelTimerComponent(),
        ]));
    return super.onLoad();
  }

  void invertControl() {
    _controlInverted = !_controlInverted;
  }

  @override
  void update(double dt) {
    final rightSideX = normaldo.position.x + normaldo.hitbox.size.x / 2;
    final bottomSideY = normaldo.position.y + normaldo.hitbox.size.y / 2;
    final leftSideX = normaldo.position.x - normaldo.hitbox.size.x / 2;
    final topSideY = normaldo.position.y - normaldo.hitbox.size.x / 2;

    if (rightSideX > size.x) {
      normaldo.position.x = size.x - normaldo.hitbox.size.x / 2;
    }
    if (bottomSideY > size.y) {
      normaldo.position.y = size.y - normaldo.hitbox.size.y / 2;
    }
    if (leftSideX < 0) {
      normaldo.position.x = normaldo.hitbox.size.x / 2;
    }
    if (topSideY < 0) {
      normaldo.position.y = normaldo.hitbox.size.y / 2;
    }
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (!controlTurnedOff) {
      if (_controlInverted) {
        normaldo.position -= event.localDelta * normaldo.speed;
      } else {
        normaldo.position += event.localDelta * normaldo.speed;
      }
    }
    super.onDragUpdate(event);
    return false;
  }
}
