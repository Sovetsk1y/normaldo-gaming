import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

class LevelTimerComponent extends TimerComponent
    with FlameBlocReader<LevelBloc, LevelState>, HasGameRef<PullUpGame> {
  LevelTimerComponent() : super(period: 10, repeat: true);

  int _currentLocationIndex = 0;

  final random = Random();
  double get _eventPeriod => 20;
  // double get _eventPeriod => (15 + Random().nextInt(16)).toDouble();

  void _onTick() {
    if (!gameRef.userCubit.state.educated) return;
    if (bloc.state.miniGame != null) return;
    if (bloc.state.figure == null && !gameRef.bossInProgress) {
      final slowMoItems = gameRef.currentLevelSlowMoItems();
      final punchItems = gameRef.currentLevelPunchItems();
      final guardItems = gameRef.currentLevelGuardItems();
      final slowMoItem = slowMoItems.isEmpty ? null : slowMoItems.random();
      final punchItem = punchItems.isEmpty ? null : punchItems.random();
      final guardItem = guardItems.isEmpty ? null : guardItems.random();
      bloc.add(
        const LevelEvent.startFigure(figure: FigureEvent.trashWall()),
        // LevelEvent.startRandomFigure(
        //   slowMoItem: slowMoItem,
        //   punch: punchItem,
        //   guard: guardItem,
        // ),
      );
    }
    add(TimerComponent(
      period: _eventPeriod,
      removeOnFinish: true,
      onTick: _onTick,
    ));
  }

  @override
  Future<void> onLoad() {
    add(TimerComponent(
        period: (80 + random.nextInt(40)).toDouble(),
        repeat: true,
        removeOnFinish: true,
        onTick: () {
          if (random.nextBool()) {
            // bloc.add(const LevelEvent.startMiniGame(game: MiniGame.shredder()));
          }
        }));
    add(TimerComponent(
      period: _eventPeriod,
      removeOnFinish: true,
      onTick: _onTick,
    ));
    return super.onLoad();
  }

  @override
  void onTick() {
    if (gameRef.scene.currentLocationIndex > _currentLocationIndex) {
      _currentLocationIndex = gameRef.scene.currentLocationIndex;

      if (!gameRef.bossInProgress) {
        bloc.add(LevelEvent.changeLevel(
          level: bloc.state.level.index + 1,
          effects: game.grid.normaldo.effectsController.effectsInProgress,
        ));
      }
    }
  }
}
