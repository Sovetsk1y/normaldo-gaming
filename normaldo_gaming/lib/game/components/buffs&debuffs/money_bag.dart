import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame_bloc/flame_bloc.dart';

import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_level_configurator.dart';
import 'package:normaldo_gaming/domain/app/sfx.dart';
import 'package:normaldo_gaming/domain/pull_up_game/aura.dart';
import 'package:normaldo_gaming/game/components/game_object.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';

class MoneyBag extends PositionComponent
    with
        CollisionCallbacks,
        HasGameRef,
        HasLevelConfigurator,
        GameObject,
        FlameBlocReader<GameSessionCubit, GameSessionState> {
  MoneyBag() : super(anchor: Anchor.center);

  @override
  Aura get aura => Aura.blue;

  @override
  Component get auraComponent => CircleComponent()
    ..size = size
    ..paint = auraPaint;

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is Normaldo) {
      bloc.addDollars(10);
      audio.playSfx(Sfx.dollarCatch);
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  Future<void> onLoad() async {
    add(auraComponent);
    add(SpriteComponent(
      size: size,
      sprite: await Sprite.load('money_bag.png'),
    ));
    add(CircleHitbox(
      radius: size.x / 2,
    )..collisionType = CollisionType.passive);
    // 4DEV
    // add(CircleComponent(
    //   radius: size.x / 2,
    //   paint: Paint()..color = Colors.white.withOpacity(0.7),
    // ));
    add(ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(
          infinite: true,
          duration: 0.3,
          reverseDuration: 0.3,
        )));

    return super.onLoad();
  }

  @override
  void update(double dt) {
    position.x -= levelConfigurator.itemSpeed(bloc.state.level) * dt;
    if (position.x < -size.x / 2) {
      removeFromParent();
    }
  }

  @override
  bool get isSoloSpawn => true;
}
