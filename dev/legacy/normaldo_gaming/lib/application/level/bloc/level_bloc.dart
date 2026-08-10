import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level/level.dart';
import 'package:normaldo_gaming/domain/pull_up_game/mini_games/mini_game.dart';
import 'package:normaldo_gaming/game/components/effects_controller.dart';

part 'level_bloc.freezed.dart';
part 'level_event.dart';
part 'level_state.dart';

class LevelBloc extends Bloc<LevelEvent, LevelState> {
  static const int limitProgressingLevel = 50;

  LevelBloc() : super(LevelState.initial()) {
    on<LevelEvent>((event, emit) => event.when(
          changeLevel: (levelIndex, effects) =>
              _onChangeLevel(levelIndex, effects, emit),
          startFigure: (figure) => _startFigure(figure, emit),
          changeSpeed: (multiplier, effects) =>
              _onChangeSpeed(multiplier, effects, emit),
          startRandomFigure: (_, slowMoItem, punch, guard) =>
              _startRandomFigure(
            emit,
            slowMoItem: slowMoItem,
            punch: punch,
            guard: guard,
          ),
          finishFigure: () => _onFigureFinished(emit),
          startMiniGame: (game) => _onStartMiniGame(game, emit),
          finishMiniGame: () {
            return emit(state.copyWith(miniGame: null));
          },
        ));
  }

  final _random = Random();
  List<FigureEvent> _figuresPool = [];

  double frequency(int level) {
    var frequency = pow(0.9, level + 1).toDouble();
    if (level > 15) {
      frequency = pow(0.9, 18).toDouble();
    }
    return frequency;
  }

  double speed(int level, List<ItemEffect> effects) {
    if (effects.contains(ItemEffect.slowMo)) {
      return state.level.speed;
    }
    var speed = (200 + (10 * level)).toDouble();
    if (level > 15) {
      speed = (200 + (20 * 12)).toDouble();
    }
    return speed;
  }

  void _onChangeSpeed(
    double speed,
    List<ItemEffect> effects,
    Emitter<LevelState> emit,
  ) {
    final level = state.level.copyWith(speed: speed);
    emit(state.copyWith(level: level));
  }

  void _onChangeLevel(
    int level,
    List<ItemEffect> effects,
    Emitter<LevelState> emit,
  ) {
    print(
        'LEVEL:${state.level.index}\nSPEED: ${speed(level, effects)}\nFREQ: ${frequency(level)}');
    emit(state.copyWith(
        level: LinearLevel(
      index: level,
      frequency: frequency(level),
      speed: speed(level, effects),
    )));
  }

  void _startFigure(
    FigureEvent figure,
    Emitter<LevelState> emit,
  ) {
    emit(
      state.copyWith(figure: figure),
    );
  }

  void _startRandomFigure(
    Emitter<LevelState> emit, {
    required Items? slowMoItem,
    required Items? punch,
    required Items? guard,
  }) {
    if (_figuresPool.isEmpty) {
      _figuresPool = [
        const FigureEvent.bigBuddyBin(),
        if (guard != null) FigureEvent.cursedPath(guard: guard),
        const FigureEvent.trashWall(),
        if (guard != null) FigureEvent.guardedPizza(guard: guard),
        FigureEvent.punchWave(punchItem: punch ?? Items.punch),
        const FigureEvent.unreachablePizza(),
        FigureEvent.only2Lines(guard: guard ?? Items.cone),
        if (slowMoItem != null) FigureEvent.slowMo(slowMoItem: slowMoItem),
      ];
    }
    final figure = _figuresPool.removeAt(_random.nextInt(_figuresPool.length));
    emit(state.copyWith(figure: figure));
  }

  void _onFigureFinished(
    Emitter<LevelState> emit,
  ) {
    emit(state.copyWith(figure: null));
  }

  void _onStartMiniGame(
    MiniGame game,
    Emitter<LevelState> emit,
  ) {
    if (state.miniGame == null) {
      emit(state.copyWith(miniGame: game));
    }
  }
}
