import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:normaldo_gaming/application/ads/ads_cubit.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';
import 'package:normaldo_gaming/game/utils/overlays.dart';

final class Tv extends SpriteComponent
    with
        CollisionCallbacks,
        HasGameRef<PullUpGame>,
        Item,
        CustomEffectItem,
        CleanScreenItem {
  @override
  ShapeHitbox get hitbox => RectangleHitbox.relative(
        Vector2.all(0.9),
        parentSize: size,
        anchor: anchor,
      );

  @override
  Items get item => Items.tv;

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Normaldo) {
      gameRef.sfxPools.playSfx(item);
      removeFromParent();
      applyEffect(() {
        gameRef.pauseEngine();
        cleanScreen();
        gameRef.adsCubit.showAd(
            type: AdType.interstitial,
            reward: const AdReward.bucksInGame(15),
            onComplete: () {
              gameRef.overlays.remove(Overlays.pauseMenu.name);
              gameRef.gameSessionCubit.togglePause();
            });
      });
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    sprite = await Sprite.load('tv.png');
    return super.onLoad();
  }
}
