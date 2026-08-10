part of 'level_bloc.dart';

@freezed
abstract class LevelEvent with _$LevelEvent {
  const factory LevelEvent.changeLevel({
    required int level,
    required List<ItemEffect> effects,
  }) = _ChangeLevel;
  const factory LevelEvent.startFigure({
    required FigureEvent figure,
  }) = _StartFigure;
  const factory LevelEvent.startMiniGame({
    required MiniGame game,
  }) = _StartMiniGame;
  const factory LevelEvent.finishMiniGame() = _FinishMiniGame;
  const factory LevelEvent.startRandomFigure({
    List<FigureEvent>? figures,
    required Items? slowMoItem,
    required Items? punch,
    required Items? guard,
  }) = _StartRandomFigure;
  const factory LevelEvent.changeSpeed({
    required double speed,
    required List<ItemEffect> effects,
  }) = _ChangeSpeed;
  const factory LevelEvent.finishFigure() = _FinishFigure;
}

@freezed
class FigureEvent with _$FigureEvent {
  static const double speedMultiplier = 1.5;

  const factory FigureEvent.trashWall() = _TrashWall;
  const factory FigureEvent.guardedPizza({required Items guard}) =
      _GuardedPizza;
  const factory FigureEvent.cursedPath({required Items guard}) = _CursedPath;
  const factory FigureEvent.punchWave({required Items punchItem}) = _PunchWave;
  const factory FigureEvent.bigBuddyBin() = _BigBuddyBin;
  const factory FigureEvent.unreachablePizza() = _UnreachablePizza;
  const factory FigureEvent.only2Lines({required Items guard}) = _Only2Times;
  const factory FigureEvent.slowMo({required Items slowMoItem}) = _SlowMo;
  const factory FigureEvent.winLabel({required Items item}) = _WinLabel;
}
