part of 'pre_death_cubit.dart';

@freezed
class PreDeathState with _$PreDeathState {
  const factory PreDeathState({
    required bool skipped,
    required double skipValue,
    required AdState adState,
  }) = _PreDeathState;

  factory PreDeathState.initial() => PreDeathState(
        skipped: false,
        skipValue: 1,
        adState: Initial(),
      );
}

sealed class AdState {}

final class Initial extends AdState {}

final class Loading extends AdState {}

final class Showing extends AdState {}

final class Finished extends AdState {}
