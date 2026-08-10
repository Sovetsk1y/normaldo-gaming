part of 'mission_cubit.dart';

@freezed
class MissionState with _$MissionState {
  const MissionState._();

  const factory MissionState({
    required Set<Mission> missions,
    required bool completing,
    required List<int> newIndexes,
  }) = _MissionState;

  bool get hasAnyCompleted => missions.any((element) => element.completed);

  factory MissionState.initial() => const MissionState(
        missions: {},
        completing: false,
        newIndexes: [],
      );
}
