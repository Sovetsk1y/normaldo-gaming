import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';

part 'mission.freezed.dart';
part 'mission.g.dart';

enum MissionType {
  collectPizza,
  crashItem,
  passItem,
  reachLocation,
  finishGame;
}

// abstract class BaseMission {
//   final bool isOneGame;
//   final int completeValue;
//   final int exp;
//   final currentValue = 0;

//   MissionType get type;

//   String get description;

//   BaseMission({
//     required this.exp,
//     required this.isOneGame,
//     required this.completeValue,
//   });
// }

@freezed
class Mission with _$Mission {
  const Mission._();

  @Assert('type == MissionType.collectPizza',
      'type must be MissionType.collectPizza')
  @Assert('currentValue >= 0', 'currentValue must be greater or equal to 0')
  factory Mission.collectPizza({
    required int exp,
    required int completeValue,
    required bool isOneGame,
    required String description,
    required int adsViewed,
    @Default(MissionType.collectPizza) MissionType type,
    @Default(0) int currentValue,
  }) = _CollectPizzaMission;

  @Assert('type == MissionType.crashItem', 'type must be MissionType.crashItem')
  @Assert('currentValue >= 0', 'currentValue must be greater or equal to 0')
  factory Mission.crashItem({
    required int exp,
    required int completeValue,
    required bool isOneGame,
    required String description,
    required int adsViewed,
    required Items item,
    @Default(MissionType.crashItem) MissionType type,
    @Default(0) int currentValue,
  }) = _CrashItemMission;

  @Assert('type == MissionType.passItem', 'type must be MissionType.passItem')
  @Assert('currentValue >= 0', 'currentValue must be greater or equal to 0')
  factory Mission.passItem({
    required int exp,
    required int completeValue,
    required bool isOneGame,
    required String description,
    required int adsViewed,
    required Items item,
    @Default(MissionType.passItem) MissionType type,
    @Default(0) int currentValue,
  }) = _PassItemMission;

  @Assert('type == MissionType.reachLocation',
      'type must be MissionType.reachLocation')
  @Assert('currentValue >= 0', 'currentValue must be greater or equal to 0')
  @Assert('isOneGame', 'reachLocation is always a one game mission')
  @Assert('completeValue > 0', 'completeValue must be greater than 0')
  factory Mission.reachLocation({
    required int exp,
    required String description,
    required int adsViewed,
    required int completeValue,
    @Default(true) bool isOneGame,
    @Default(MissionType.reachLocation) MissionType type,
    @Default(0) int currentValue,
  }) = _ReachLocationMission;

  @Assert(
      'type == MissionType.finishGame', 'type must be MissionType.finishGame')
  @Assert('currentValue >= 0', 'currentValue must be greater or equal to 0')
  @Assert('isOneGame', 'reachLocation is always a one game mission')
  @Assert('completeValue > 0', 'completeValue must be greater than 0')
  factory Mission.finishGame({
    required int exp,
    required String description,
    required int adsViewed,
    required int completeValue,
    @Default(true) bool isOneGame,
    @Default(MissionType.finishGame) MissionType type,
    @Default(0) int currentValue,
  }) = _FinishGameMission;

  bool get completed => currentValue >= completeValue || adsViewed >= exp;
  String get progressText => maybeWhen(
        reachLocation: (exp, description, adsViewed, completeValue, isOneGame,
                type, currentValue) =>
            '(${completed ? 1 : 0}/1)',
        finishGame: (exp, description, adsViewed, completeValue, isOneGame,
                type, currentValue) =>
            '(${completed ? 1 : 0}/1)',
        orElse: () => '($currentValue/$completeValue)',
      );

  factory Mission.fromJson(Map<String, dynamic> json) =>
      _$MissionFromJson(json);
}

// final class CollectPizzaMission extends Mission {
//   CollectPizzaMission({
//     required super.exp,
//     required super.completeValue,
//     required super.isOneGame,
//   });

//   @override
//   MissionType get type => MissionType.collectPizza;

//   @override
//   bool get completed => currentValue >= completeValue;

//   @override
//   String get description => '$runtimeType $isOneGame $completeValue'.tr();
// }

// final class CrashItemInOneGameMission extends Mission {
//   CrashItemInOneGameMission({
//     required super.exp,
//     required super.value,
//     required this.item,
//     super.completed,
//   }) : super(isOneGame: true, description: 'Crash item in one game');

//   final Items item;

//   @override
//   MissionType get type => MissionType.crashItem;
// }

// final class FinishGameAtLevelMission extends Mission {
//   FinishGameAtLevelMission({
//     required super.exp,
//     required super.description,
//     required super.value,
//     super.completed,
//   }) : super(
//           isOneGame: true,
//         );

//   @override
//   MissionType get type => MissionType.finishGame;
// }

// <––––––––––––––––––––––––– LEGACY –––––––––––––––––––––––––>

// sealed class Mission {
//   final String description;
//   final int exp;
//   final bool isOneGame;
//   final int value;
//   bool completed;

//   Mission({
//     required this.description,
//     required this.exp,
//     required this.isOneGame,
//     required this.value,
//     this.completed = false,
//   });

//   MissionType get type;
// }

// enum MissionType {
//   collectPizza,
//   crashItem,
//   passItem,
//   reachLocation,
//   finishGame;
// }

// final class CollectPizzaInOneGameMission extends Mission {
//   CollectPizzaInOneGameMission({
//     required super.exp,
//     required super.value,
//     super.completed,
//   }) : super(isOneGame: true, description: 'Collect pizzas in one game');

//   @override
//   MissionType get type => MissionType.collectPizza;
// }

// final class CrashItemInOneGameMission extends Mission {
//   CrashItemInOneGameMission({
//     required super.exp,
//     required super.value,
//     required this.item,
//     super.completed,
//   }) : super(isOneGame: true, description: 'Crash item in one game');

//   final Items item;

//   @override
//   MissionType get type => MissionType.crashItem;
// }

// final class FinishGameAtLevelMission extends Mission {
//   FinishGameAtLevelMission({
//     required super.exp,
//     required super.description,
//     required super.value,
//     super.completed,
//   }) : super(
//           isOneGame: true,
//         );

//   @override
//   MissionType get type => MissionType.finishGame;
// }
