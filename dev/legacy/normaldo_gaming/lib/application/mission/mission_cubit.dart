import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/domain/pull_up_game/mission.dart';
import 'package:normaldo_gaming/domain/pull_up_game/missions/missions_repository.dart';

part 'mission_state.dart';
part 'mission_cubit.freezed.dart';

class MissionCubit extends HydratedCubit<MissionState> {
  final MissionsRepository _missionsRepository;

  MissionCubit(this._missionsRepository) : super(MissionState.initial());

  void resetAllProgress() {
    final newMissions = <Mission>[];
    for (final mission in state.missions) {
      if (mission.currentValue != 0) {
        newMissions.add(mission.copyWith(currentValue: 0));
      } else {
        newMissions.add(mission);
      }
    }
    emit(state.copyWith(missions: newMissions.toSet()));
  }

  void resetOneGames() {
    final newMissions = <Mission>[];
    for (final mission in state.missions) {
      if (mission.isOneGame && mission.currentValue != 0) {
        newMissions.add(mission.copyWith(currentValue: 0));
      } else {
        newMissions.add(mission);
      }
    }
    emit(state.copyWith(missions: newMissions.toSet()));
  }

  void applyProgress(
    MissionType type, {
    Items? item,
    int? currentLocationIndex,
  }) {
    if (!_hasMissionOfType(type, item: item)) return;
    if ((type == MissionType.crashItem || type == MissionType.passItem) &&
        item == null) {
      throw UnexpectedError();
    }
    if (type == MissionType.finishGame && currentLocationIndex == null) {
      throw UnexpectedError();
    }

    final mission = _missionOfType(type, item: item);
    mission.maybeWhen(
      finishGame: (exp, description, adsViewed, completeValue, isOneGame, type,
          currentValue) {
        if (!mission.completed) {
          final index = state.missions.toList().indexOf(mission);
          final replacement = mission.copyWith(
              currentValue: (currentLocationIndex ?? 0) == mission.completeValue
                  ? mission.completeValue
                  : 0);
          final newMissions = List<Mission>.from(state.missions)
            ..removeAt(index)
            ..insert(index, replacement);
          emit(state.copyWith(missions: newMissions.toSet()));
        }
      },
      reachLocation: (exp, description, adsViewed, completeValue, isOneGame,
          type, currentValue) {
        if (!mission.completed) {
          final index = state.missions.toList().indexOf(mission);
          final replacement =
              mission.copyWith(currentValue: mission.currentValue + 1);
          final newMissions = List<Mission>.from(state.missions)
            ..removeAt(index)
            ..insert(index, replacement);
          print(replacement.currentValue);
          emit(state.copyWith(missions: newMissions.toSet()));
        }
        return;
      },
      crashItem: (exp, completeValue, isOneGame, description, adsViewed, mItem,
          type, currentValue) {
        if (!mission.completed && mItem == item) {
          final index = state.missions.toList().indexOf(mission);
          final replacement =
              mission.copyWith(currentValue: mission.currentValue + 1);
          final newMissions = List<Mission>.from(state.missions)
            ..removeAt(index)
            ..insert(index, replacement);
          emit(state.copyWith(missions: newMissions.toSet()));
        }
        return;
      },
      passItem: (exp, completeValue, isOneGame, description, adsViewed, mItem,
          type, currentValue) {
        if (!mission.completed && mItem == item) {
          if ((currentLocationIndex ?? 0) >= completeValue) {
            return;
          } else {
            final index = state.missions.toList().indexOf(mission);
            final replacement =
                mission.copyWith(currentValue: mission.currentValue + 1);
            final newMissions = List<Mission>.from(state.missions)
              ..removeAt(index)
              ..insert(index, replacement);
            emit(state.copyWith(missions: newMissions.toSet()));
          }
        }
        return;
      },
      orElse: () {
        if (!mission.completed) {
          final index = state.missions.toList().indexOf(mission);
          final replacement =
              mission.copyWith(currentValue: mission.currentValue + 1);
          final newMissions = List<Mission>.from(state.missions)
            ..removeAt(index)
            ..insert(index, replacement);
          emit(state.copyWith(missions: newMissions.toSet()));
        }
      },
    );
  }

  Mission generateNewMission(Set<MissionType> excludeTypes) {
    return _missionsRepository
        .generateMissionsOfType(
          amount: 1,
          excludeTypes: excludeTypes,
        )
        .first;
  }

  void updateMissions(List<Mission> missions) {
    emit(state.copyWith(missions: missions.toSet()));
  }

  void completeMission(Mission mission) {
    final newMissions = List<Mission>.from(state.missions);
    final first = newMissions.removeAt(0);
    final second = newMissions.removeAt(0);
    newMissions.insert(0, second.copyWith(currentValue: second.completeValue));
    newMissions.insert(0, first.copyWith(currentValue: first.completeValue));
    emit(state.copyWith(
      missions: newMissions.toSet(),
      completing: true,
    ));
    // final index = state.missions.toList().indexOf(mission);
    // final replacement = mission.copyWith(currentValue: mission.completeValue);
    // final newMissions = List<Mission>.from(state.missions)
    //   ..removeAt(index)
    //   ..insert(index, replacement);
    // emit(state.copyWith(missions: newMissions.toSet()));
  }

  void removeMission(int index, UserCubit userCubit) {
    final newMissions = List<Mission>.from(state.missions);
    final removed = newMissions.removeAt(index);
    userCubit.addExp(removed.exp);
    emit(state.copyWith(
      missions: newMissions.toSet(),
      completing: false,
    ));
  }

  void addAdView(MissionType type) {
    if (!_hasMissionOfType(type)) return;

    final mission = _missionOfType(type);
    throw UnimplementedError();
    if (!mission.completed) {
      final start = state.missions.toList().indexOf(mission) - 1;
      final end = state.missions.toList().indexOf(mission) + 1;
      final replacements = [
        mission.copyWith(currentValue: mission.adsViewed + 1)
      ];
      final newMissions = List<Mission>.from(state.missions)
        ..replaceRange(start, end, replacements);
      emit(state.copyWith(missions: newMissions.toSet()));
      // rearrangeCompletedMissions();
    }
  }

  void rearrangeCompletedMissions(List<int> indexes) {
    final newMissions = Set<Mission>.from(state.missions).toList();
    final restAmount = 3 - state.missions.length;
    if (restAmount == 0) return;
    final genMissions = _missionsRepository.generateMissionsOfType(
      amount: restAmount,
      excludeTypes: state.missions.map((e) => e.type).toSet(),
    );
    for (var i = 0; i < genMissions.length; i++) {
      final m = genMissions.toList()[i];
      final index = indexes[i];
      newMissions.insert(index, m);
    }
    emit(state.copyWith(
      missions: newMissions.toSet(),
      newIndexes: indexes,
    ));
  }

  // <––––––––––––––––––––––––– PRIVATE METHODS –––––––––––––––––––––––––>

  bool _hasMissionOfType(MissionType type, {Items? item}) {
    return state.missions.any((element) =>
        element.type == type &&
        element.maybeMap(
          crashItem: (mission) => mission.item == item,
          orElse: () => true,
        ));
  }

  Mission _missionOfType(MissionType type, {Items? item}) {
    return state.missions.firstWhere(
      (mission) =>
          mission.maybeMap(
            crashItem: (mission) => mission.item == item,
            orElse: () => true,
          ) &&
          mission.type == type,
    );
  }

  // <––––––––––––––––––––––––– HYDRATING –––––––––––––––––––––––––>

  @override
  MissionState? fromJson(Map<String, dynamic> json) {
    final missionsList = json['missions'] as List?;
    if (missionsList == null) return null;
    final missions = missionsList.map((e) => Mission.fromJson(e)).toSet();
    return MissionState(
      missions: missions,
      completing: false,
      newIndexes: [],
    );
  }

  @override
  Map<String, dynamic>? toJson(MissionState state) {
    return {
      'missions': state.missions.toList().map((e) => e.toJson()).toList(),
    };
  }
}
