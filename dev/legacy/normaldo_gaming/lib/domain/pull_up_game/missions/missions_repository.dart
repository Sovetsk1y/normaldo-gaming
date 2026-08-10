import 'package:normaldo_gaming/domain/pull_up_game/mission.dart';

abstract class MissionsRepository {
  Set<Mission> generateMissionsOfType({
    required int amount,
    Set<MissionType> excludeTypes = const {},
  });
}
