part of 'level_bloc.dart';

@freezed
class LevelState with _$LevelState {
  const factory LevelState({
    required LinearLevel level,
    FigureEvent? figure,
    MiniGame? miniGame,
  }) = _LevelState;

  factory LevelState.initial() => LevelState(
          level: LinearLevel(
        index: 0,
        frequency: 0.5,
        speed: 200,
      ));
}
