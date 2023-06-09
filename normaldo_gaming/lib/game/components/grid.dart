import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/figure_event_component.dart';
import 'package:normaldo_gaming/game/components/game_object.dart';
import 'package:normaldo_gaming/game/components/level_timer_component.dart';

import 'normaldo.dart';

class Grid extends PositionComponent
    with
        DragCallbacks,
        HasGameRef,
        FlameBlocReader<LevelBloc, LevelState>,
        FlameBlocListenable<LevelBloc, LevelState> {
  static const linesCount = 5;

  Grid({required this.gameSessionCubit, required this.levelBloc});

  final GameSessionCubit gameSessionCubit;
  final LevelBloc levelBloc;

  late final Normaldo normaldo;

  double _lineSize = 0;
  double get lineSize => _lineSize;

  Map<int, double> _stoppedLines = {};
  List<double> _linesCentersY = [];
  List<double> get linesCentersY => _linesCentersY;

  List<double> lineXAllocation(double xSize) {
    return List.generate(size.x ~/ (xSize / 2),
        (index) => (size.x / (xSize / 2) * index) + (xSize));
  }

  TimerComponent? _itemsCreator;

  @override
  bool listenWhen(LevelState previousState, LevelState newState) {
    return previousState.level != newState.level;
  }

  @override
  void onNewState(LevelState state) async {
    if (_itemsCreator != null) remove(_itemsCreator!);
    _itemsCreator = TimerComponent(
      period: state.level.frequency,
      repeat: true,
      onTick: () {
        if (state.figure != null) return;
        add(FlameBlocProvider<LevelBloc, LevelState>.value(
            value: levelBloc,
            children: [
              ...state.level.next().map((e) => e.item.component()
                ..size = e.item.getSize(lineSize)
                ..position = Vector2(
                    gameRef.size.x + e.item.getSize(lineSize).x * 2,
                    _linesCentersY[
                        e.line ?? Random().nextInt(_linesCentersY.length)]))
            ]));
      },
    );
    if (state.figure != null) _itemsCreator?.timer.pause();
    add(_itemsCreator!);
  }

  void stopLine(int index) {
    assert(index >= 0 && index < 5);
    if (_stoppedLines.keys.contains(index)) return;
    _stoppedLines[index] = _linesCentersY.removeAt(index);
  }

  void resumeLines() {
    final toRemove = <int>[];
    for (final entry in _stoppedLines.entries) {
      _linesCentersY.add(entry.value);
      toRemove.add(entry.key);
    }
    for (final key in toRemove) {
      _stoppedLines.remove(key);
    }
    _linesCentersY.sort();
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
        return ((component is FlameBlocProvider &&
                    component.children
                        .every((element) => element is GameObject) ||
                component is FigureEventComponent) ||
            component is GameObject);
      },
    );
  }

  @override
  Future<void> onLoad() async {
    size = Vector2(gameRef.size.x, gameRef.size.y);
    _lineSize = size.y / linesCount;
    normaldo = Normaldo(size: Vector2.all(lineSize * 0.9))
      ..position = Vector2(size.x / 2, size.y / 2);
    for (int i = 1; i <= linesCount; i++) {
      _linesCentersY.add(_getCenterOfLine(i));

      // 4DEV
      // add(RectangleComponent(
      //   position: Vector2(0, i * lineSize),
      //   size: Vector2(size.x, 1),
      //   paint: Paint()..color = BasicPalette.yellow.color,
      // ));
    }
    _itemsCreator = TimerComponent(
        period: levelBloc.state.level.frequency,
        repeat: true,
        onTick: () {
          if (levelBloc.state.figure != null) return;
          add(FlameBlocProvider<LevelBloc, LevelState>.value(
              value: levelBloc,
              children: [
                ...levelBloc.state.level.next().map((e) => e.item.component()
                  ..size = e.item.getSize(lineSize)
                  ..position = Vector2(
                      size.x + e.item.getSize(lineSize).x * 2,
                      _linesCentersY[
                          e.line ?? Random().nextInt(_linesCentersY.length)]))
              ]));
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
          _itemsCreator?.timer.pause();
          add(TimerComponent(
              period: state.level.frequency,
              removeOnFinish: true,
              onTick: () {
                add(
                  FigureEventComponent(
                    figure: state.figure!,
                    lineSize: lineSize,
                    linesCentersY: linesCentersY,
                    onFinish: () {
                      bloc.add(const LevelEvent.finishFigure());
                    },
                  )
                    ..position = Vector2(0, 0)
                    ..size = size,
                );
              }));
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

  @override
  void update(double dt) {
    final rightSideX = normaldo.position.x + normaldo.size.x / 2;
    final bottomSideY = normaldo.position.y + normaldo.size.y / 2;
    final leftSideX = normaldo.position.x - normaldo.size.x / 2;
    final topSideY = normaldo.position.y - normaldo.size.x / 2;

    if (rightSideX > size.x) {
      normaldo.position.x = size.x - normaldo.size.x / 2;
    }
    if (bottomSideY > size.y) {
      normaldo.position.y = size.y - normaldo.size.y / 2;
    }
    if (leftSideX < 0) {
      normaldo.position.x = normaldo.size.x / 2;
    }
    if (topSideY < 0) {
      normaldo.position.y = normaldo.size.y / 2;
    }
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (bloc.state.effects.entries
        .any((entry) => entry.value.key == Items.cocktail)) {
      normaldo.position += event.delta * 0.3;
    } else {
      normaldo.position += event.delta * _getFatMultiplier(normaldo);
    }
    super.onDragUpdate(event);
    return false;
  }

  double _getFatMultiplier(Normaldo normaldo) {
    switch (normaldo.current) {
      case NormaldoFatState.skinny:
      case NormaldoFatState.skinnyEat:
      case NormaldoFatState.skinnyDead:
        return 1;
      case NormaldoFatState.slim:
      case NormaldoFatState.slimEat:
      case NormaldoFatState.slimDead:
        return 0.7;
      case NormaldoFatState.fat:
      case NormaldoFatState.fatEat:
      case NormaldoFatState.fatDead:
        return 0.5;
      case NormaldoFatState.uberFat:
      case NormaldoFatState.uberFatEat:
      case NormaldoFatState.uberFatDead:
        return 0.4;
      case null:
        throw UnexpectedError();
    }
  }

  double _getCenterOfLine(int line) {
    int multiplier;
    switch (line) {
      case 1:
        multiplier = 1;
        break;
      case 2:
        multiplier = 3;
        break;
      case 3:
        multiplier = 5;
        break;
      case 4:
        multiplier = 7;
        break;
      case 5:
        multiplier = 9;
        break;
      default:
        throw UnexpectedError();
    }
    return (size.y / linesCount / 2 * multiplier);
  }
}
