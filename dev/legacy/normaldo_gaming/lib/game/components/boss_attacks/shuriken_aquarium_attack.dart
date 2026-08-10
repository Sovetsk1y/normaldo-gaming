import 'package:normaldo_gaming/game/components/effects/effects.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import './attack.dart';

final class ShurikenAquariumAttack extends Attack with Effects {
  @override
  void pause(Boss boss) {
    // TODO: implement pause
  }

  @override
  void run(Boss boss) {
    inProgress = true;
    boss.add(fadeOutEffect(duration: 0.3));
  }

  @override
  void stop(Boss boss) {
    // TODO: implement stop
  }
}
