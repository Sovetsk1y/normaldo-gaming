// import 'dart:async';

// import 'package:flame/collisions.dart';
// import 'package:flame/components.dart';
// import 'package:flame_bloc/flame_bloc.dart';
// import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
// import 'package:normaldo_gaming/domain/app/sfx.dart';
// import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
// import 'package:normaldo_gaming/game/components/item_components/bosses/shredder/shredder.dart';
// import 'package:normaldo_gaming/game/components/item_components/punch.dart';
// import 'package:normaldo_gaming/game/components/game_object.dart';
// import 'package:normaldo_gaming/game/components/normaldo.dart';
// import 'package:normaldo_gaming/game/pull_up_game.dart';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

class ShredderSword extends PositionComponent
    with CollisionCallbacks, HasGameRef<PullUpGame>, Item, AttackingItem {
  ShredderSword() : super(anchor: Anchor.center);

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    attack(other);
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  Future<void> onLoad() async {
    speed = gameRef.levelBloc.state.level.speed;
    add(SpriteComponent(
      size: size,
      sprite: await Sprite.load('shredder_sword.png'),
    ));

    return super.onLoad();
  }

  @override
  Items get item => Items.shredderSword;

  @override
  int get damage => 1;

  @override
  PositionComponent get hitbox => RectangleHitbox.relative(
        Vector2.all(0.8),
        parentSize: size,
        anchor: anchor,
      );

  @override
  int get strength => 5;
}
