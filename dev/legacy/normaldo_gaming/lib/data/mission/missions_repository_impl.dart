import 'dart:math';

import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/domain/pull_up_game/mission.dart';
import 'package:normaldo_gaming/domain/pull_up_game/missions/missions_repository.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

// 1. миссию на исследование

final class MissionsRepositoryImpl implements MissionsRepository {
  final _rnd = Random();

  @override
  Set<Mission> generateMissionsOfType({
    required int amount,
    Set<MissionType> excludeTypes = const {},
  }) {
    assert(amount > 0, 'amount must be greater than 0');
    assert(amount < MissionType.values.length - excludeTypes.length);

    final availableTypes = List<MissionType>.from(MissionType.values);
    availableTypes.removeWhere((e) => excludeTypes.contains(e));
    availableTypes.shuffle();

    List<Mission> missions = [];

    for (final type in availableTypes) {
      missions.add(_generateMissionOfType(type));
      if (missions.length == amount) break;
    }

    return missions.toSet();
  }

  Mission _generateMissionOfType(MissionType type) {
    return switch (type) {
      MissionType.collectPizza => _generateCollectPizzaMission(),
      MissionType.crashItem => _generateCrashItemMission(),
      MissionType.passItem => _generatePassItemMission(),
      MissionType.reachLocation => _generateReachLocationMission(),
      MissionType.finishGame => _generateFinishGameMission(),
    };
  }

  Mission _generateCollectPizzaMission() {
    int expFromPizza(int pizza, bool isOneGame) {
      if (isOneGame) {
        assert(pizza >= 10,
            'There must be more or 10 pizzas in one game mission of that type');
        if (pizza >= 100) return 3;
        if (pizza >= 50) return 2;
        return 1;
      } else {
        assert(pizza >= 50,
            'There must be more or 50 pizzas in NOT one game mission of that type');
        if (pizza >= 300) return 4;
        if (pizza >= 150) return 3;
        return 2;
      }
    }

    final isOneGame = _rnd.nextBool();

    if (isOneGame) {
      final completePizza = 10 + _rnd.nextInt(91);
      return Mission.collectPizza(
        exp: expFromPizza(completePizza, isOneGame),
        completeValue: completePizza,
        isOneGame: isOneGame,
        description: 'collect pizza in one game',
        adsViewed: 0,
      );
    } else {
      final completePizza = 50 + _rnd.nextInt(251);
      return Mission.collectPizza(
        exp: expFromPizza(completePizza, isOneGame),
        completeValue: completePizza,
        isOneGame: isOneGame,
        description: 'collect pizza over games',
        adsViewed: 0,
      );
    }
  }

  Mission _generateCrashItemMission() {
    int expFromCrashes(int crashes, bool isOneGame) {
      if (isOneGame) {
        assert(crashes >= 1 && crashes <= 3,
            'There must be more or 1 crashes and less or 3 in one game mission of that type');
        return crashes;
      } else {
        assert(crashes >= 3 && crashes <= 6,
            'There must be more or 3 crashes and less or 6 in NOT one game mission of that type');
        if (crashes == 6) return 5;
        if (crashes == 5) return 4;
        if (crashes == 4) return 3;
        return 2;
      }
    }

    final isOneGame = _rnd.nextBool();

    // const disabledItems = [
    //   Items.hugeItem,
    //   Items.shredder,
    //   Items.shredderSword,
    //   Items.shuriken,
    // ];
    final availableItems = [
      Items.bananaPeel,
      Items.trashBin,
      Items.roadSign,
      Items.cone,
      Items.homeless,
    ];
    final item = availableItems[_rnd.nextInt(availableItems.length)];

    if (isOneGame) {
      final completeValue = 1 + _rnd.nextInt(3);
      final mission = Mission.crashItem(
        exp: expFromCrashes(completeValue, isOneGame),
        completeValue: completeValue,
        isOneGame: isOneGame,
        description: 'crash item in one game',
        adsViewed: 0,
        item: item,
      );
      return mission;
    } else {
      final completeValue = 3 + _rnd.nextInt(4);
      final mission = Mission.crashItem(
        exp: expFromCrashes(completeValue, isOneGame),
        completeValue: completeValue,
        isOneGame: isOneGame,
        description: 'crash item over games',
        adsViewed: 0,
        item: item,
      );
      return mission;
    }
  }

  Mission _generatePassItemMission() {
    int expFromPasses(int passes, bool isOneGame) {
      if (isOneGame) {
        assert(passes >= 1 && passes <= 3,
            'There must be more or 1 passes and less or 3 in one game mission of that type');
        return passes;
      } else {
        assert(passes >= 3 && passes <= 6,
            'There must be more or 3 passes and less or 6 in NOT one game mission of that type');
        if (passes == 6) return 5;
        if (passes == 5) return 4;
        if (passes == 4) return 3;
        return 2;
      }
    }

    final availableItems = [
      Items.bananaPeel,
      Items.trashBin,
      Items.roadSign,
      Items.cone,
      Items.homeless,
    ];
    final item = availableItems[_rnd.nextInt(availableItems.length)];

    final isOneGame = _rnd.nextBool();

    if (isOneGame) {
      final completeValue = 1 + _rnd.nextInt(3);
      final mission = Mission.passItem(
        exp: expFromPasses(completeValue, isOneGame),
        completeValue: completeValue,
        isOneGame: isOneGame,
        description: 'pass item in one game',
        adsViewed: 0,
        item: item,
      );
      return mission;
    } else {
      final completeValue = 3 + _rnd.nextInt(4);
      final mission = Mission.passItem(
        exp: expFromPasses(completeValue, isOneGame),
        completeValue: completeValue,
        isOneGame: isOneGame,
        description: 'pass item over games',
        adsViewed: 0,
        item: item,
      );
      return mission;
    }
  }

  Mission _generateReachLocationMission() {
    int expFromLocation(String location) {
      assert(
          Utils.locationExp.keys.contains(location), 'Unknown location string');
      return Utils.locationExp[location]!;
    }

    int completeValueFromLocation(String location) {
      assert(Utils.locationIndexes.keys.contains(location),
          'Unknown location string');
      return Utils.locationIndexes[location]!;
    }

    final location =
        Utils.locationExp.keys.toList()[_rnd.nextInt(Utils.locationExp.length)];

    return Mission.reachLocation(
      exp: expFromLocation(location),
      completeValue: completeValueFromLocation(location),
      description: 'reach location',
      adsViewed: 0,
    );
  }

  Mission _generateFinishGameMission() {
    int expFromLocation(String location) {
      assert(
          Utils.locationExp.keys.contains(location), 'Unknown location string');
      return Utils.locationExp[location]!;
    }

    int completeValueFromLocation(String location) {
      assert(Utils.locationIndexes.keys.contains(location),
          'Unknown location string');
      return Utils.locationIndexes[location]!;
    }

    final location =
        Utils.locationExp.keys.toList()[_rnd.nextInt(Utils.locationExp.length)];

    return Mission.finishGame(
      exp: expFromLocation(location),
      completeValue: completeValueFromLocation(location),
      description: 'finish game at location',
      adsViewed: 0,
    );
  }
}
