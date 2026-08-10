import 'dart:async';
import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/domain/pull_up_game/level_manager.dart';
import 'package:normaldo_gaming/domain/pull_up_game/mission.dart';
import 'package:normaldo_gaming/game/components/effects_controller.dart';
import 'package:normaldo_gaming/game/components/grid.dart';
import 'package:normaldo_gaming/game/components/item_components/bosses/boss_component.dart';
import 'package:normaldo_gaming/game/components/item_components/explosion_component.dart';
import 'package:normaldo_gaming/game/components/normaldo.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';
import 'package:normaldo_gaming/game/utils/utils.dart';

mixin Item on PositionComponent, HasGameRef<PullUpGame>, CollisionCallbacks {
  Items get item;
  bool get autoRemove => true;
  void Function()? get onRemoved => null;
  bool get collidable => _collidable;
  bool get moving => _moving;
  double get speed => _speed * _speedMultiplier;
  PositionComponent get hitbox;

  late double _speed = game.levelBloc.state.level.speed;

  set speed(double newValue) {
    _speed = newValue;
  }

  set speedMultiplier(double newValue) {
    _speedMultiplier = newValue;
  }

  set moving(bool newValue) {
    _moving = newValue;
  }

  set collidable(bool newValue) {
    _collidable = newValue;
  }

  LevelManager get levelManager => game.levelManager;

  var _collidable = true;
  double _speedMultiplier = 1;
  bool _moving = true;

  @override
  Anchor get anchor => Anchor.center;

  @override
  @mustCallSuper
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (!collidable) return;
    if ((other is Item) && !other.collidable) return;
    if (other is Normaldo && other.skin.resistanceToItems.contains(item)) {
      other.resist();
      removeFromParent();
      return;
    }
    if (other is Normaldo && !other.immortal) {
      gameRef.missionCubit.applyProgress(MissionType.crashItem, item: item);
    }
    if (other is KillingItem ||
        (other is AttackingItem &&
            this is! AttackingItem &&
            this is! NormaldoAttack)) {
      if (position.x < gameRef.size.x) {
        gameRef.sfxPools.playItemHitSfx();
      }
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  FutureOr<void> onLoad() async {
    add(hitbox..position = Vector2(size.x / 2, size.y / 2));
    anchor = anchor;
    game.levelBloc.stream.listen((state) {
      if (_moving) {
        _speed = state.level.speed;
      }
    });
    return super.onLoad();
  }

  @override
  void update(double dt) {
    if (moving) {
      position.x -= speed * dt;
    }
    if (autoRemove) {
      if (position.x < -size.x) {
        gameRef.missionCubit.applyProgress(MissionType.passItem, item: item);
        removeFromParent();
      }
    }
  }

  @override
  void onRemove() {
    onRemoved?.call();
    super.onRemove();
  }
}

// ✅
mixin AttackingItem on Item {
  int _strength = 1;
  int get strength => _strength;
  int get damage;

  set strength(int newStrength) {
    _strength = newStrength;
  }

  void attack(PositionComponent other) {
    if (other is Boss) return;
    if (other is Normaldo && other.skin.resistanceToItems.contains(item)) {
      gameRef.grid.showCollisionComics(
        type: ComicsType.resist,
        position: position,
        size: size,
      );
      gameRef.missionCubit.applyProgress(MissionType.crashItem, item: item);
      removeFromParent();
      return;
    }
    if (other is Normaldo && !other.immortal && !other.hasImmuneTo(item)) {
      other.takeHit(damage: damage);
      gameRef.missionCubit.applyProgress(MissionType.crashItem, item: item);
      gameRef.grid.showCollisionComics(
        type: ComicsType.hurt,
        position: position,
        size: size,
      );
      removeFromParent();
    }
    if (other is AttackingItem && other.collidable && strength > 0) {
      if (other.strength >= strength) {
        if (position.x < gameRef.size.x) {
          gameRef.sfxPools.playItemHitSfx();
        }
        removeFromParent();
      }
    }
  }
}

// ✅
mixin SlowingItem on Item {
  void slow() {
    if (!game.grid.normaldo.hasImmuneTo(item) &&
        !game.grid.normaldo.skin.resistanceToItems.contains(item)) {
      game.grid.normaldo.effectsController.addEffect(
        ItemEffect.slow,
        Utils.generateCocktailDuration(),
      );
      removeFromParent();
    }
  }
}

mixin SpeedUpItem on Item {
  void speedUp() {
    game.grid.normaldo.effectsController.addEffect(
      ItemEffect.speedUp,
      Utils.generateCocktailDuration(),
    );
  }
}

// ✅
mixin CleanScreenItem on Item {
  void cleanScreen([List<Items>? except]) {
    final grid = game.grid;
    Vibrate.vibrate();
    removeFromParent();
    grid.removeAllItems(
        exclude: grid.children
            .where((e) => e is Item && (except?.contains(e.item) ?? false))
            .toList());
    grid.add(ExplosionComponent()..size = grid.size);
  }
}

// ✅
mixin KillingItem on Item {
  void kill(PositionComponent other) {
    if (other is Normaldo && other.skin.resistanceToItems.contains(item)) {
      gameRef.grid.showCollisionComics(
        type: ComicsType.resist,
        position: position,
        size: size,
      );
      return;
    }
    if (other is Normaldo && !other.skin.resistanceToItems.contains(item)) {
      game.gameSessionCubit.die(
        gameRef.missionCubit,
        gameRef.scene.currentLocationIndex,
      );
    }
  }
}

// ✅
mixin ImmortalityItem on Item {
  void immortality({double? duration}) {
    game.grid.normaldo.effectsController.addEffect(
      ItemEffect.immortality,
      duration ?? 2 + Random().nextInt(4).toDouble(),
    );
  }
}

mixin ImmuneItem on Item {
  void immuneTo<T extends Item>() {
    if (T == AttackingItem) {
      game.grid.normaldo.effectsController.addEffect(
        ItemEffect.immuneToAttackingItems,
        Utils.generateCocktailDuration(),
      );
    } else if (T == SlowingItem) {
      game.grid.normaldo.effectsController.addEffect(
        ItemEffect.immuneToSlowingItems,
        Utils.generateCocktailDuration(),
      );
    }
  }
}

// ✅
mixin MoneytakeItem on Item {
  void takeMoney(int amount) {
    final normaldo = game.grid.normaldo;
    if (game.gameSessionCubit.state.dollars == 0) {
      normaldo.takeHit();
    } else {
      game.gameSessionCubit.takeDollars(amount);
      game.grid.normaldo.notify(
        text: '-$amount bucks',
        color: Colors.red,
      );
    }
  }
}

// ✅
mixin MoneygiveItem on Item {
  void giveMoney(int amount) {
    if (game.grid.normaldo.canGetX3Money) {
      game.gameSessionCubit.addDollars(amount * 3);
      game.grid.normaldo.showX3Money();
    } else {
      game.gameSessionCubit.addDollars(amount);
    }

    gameRef.sfxPools.playMoneygiveSfx();
  }

  @override
  FutureOr<void> onLoad() async {
    add(ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(
          infinite: true,
          duration: 0.3,
          reverseDuration: 0.3,
        )));
    return super.onLoad();
  }
}

// ✅
mixin SlowMoItem on Item {
  void slowMo({double? duration}) {
    assert(duration == null || duration > 0);
    game.grid.normaldo.effectsController.addEffect(
      ItemEffect.slowMo,
      duration ?? Utils.generateHourglassDuration(),
    );
  }
}

// ✅
mixin PizzaGivingItem on Item {
  void givePizza() {
    game.gameSessionCubit.eatPizza();
    gameRef.missionCubit.applyProgress(MissionType.collectPizza, item: item);
    game.grid.normaldo.increaseFatPoints(1);
    removeFromParent();
  }

  @override
  FutureOr<void> onLoad() {
    add(ScaleEffect.to(
        Vector2.all(1.2),
        EffectController(
          infinite: true,
          duration: 0.3,
          reverseDuration: 0.3,
        )));
    return super.onLoad();
  }
}

// ✅
mixin CustomEffectItem on Item {
  void applyEffect(void Function() onEffect) {
    onEffect();
  }
}

mixin NormaldoAttack on Item {
  void attack(Boss boss);
}

mixin Eatable on Item {}
