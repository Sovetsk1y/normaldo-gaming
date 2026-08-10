import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';

abstract base class Attack<T extends Boss> {
  bool finished = false;
  bool inProgress = false;
  bool hasNormaldoAttack = false;

  void run(Boss boss);
  void pause(Boss boss);
  void stop(Boss boss);
}
