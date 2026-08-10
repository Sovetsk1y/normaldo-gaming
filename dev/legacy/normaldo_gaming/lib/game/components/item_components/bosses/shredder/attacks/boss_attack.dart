import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';

abstract base class BossAttack {
  bool get inProgress;
  bool get completed;

  void start(Boss boss, Grid grid);

  void flipIfNeeded(Boss boss, Normaldo normaldo) {
    if (boss.center.x > normaldo.center.x && boss.isFlippedHorizontally) {
      boss.flipHorizontallyAroundCenter();
    }
    if (boss.center.x < normaldo.center.x && !boss.isFlippedHorizontally) {
      boss.flipHorizontallyAroundCenter();
    }
  }
}
