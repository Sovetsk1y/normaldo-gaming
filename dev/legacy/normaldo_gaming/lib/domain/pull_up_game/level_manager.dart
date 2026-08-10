import 'package:normaldo_gaming/domain/pull_up_game/entities/reward.dart';
import 'package:normaldo_gaming/domain/user/entities/user.dart';

abstract interface class LevelManager {
  static const maxLevelExp = -1;

  int nextLevelExp(User user);

  String rank(User user);

  List<List<Reward>> get levelUpRewards;

  bool isMaxLevel(User user);
}
