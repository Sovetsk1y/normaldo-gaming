import 'package:flame/components.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/domain/pull_up_game/items.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

enum ItemEffect {
  slow,
  slowMo,
  immortality,
  disorient,
  speedUp,
  immuneToSlowingItems,
  immuneToAttackingItems,
}

class EffectsController extends PositionComponent
    with FlameBlocReader<LevelBloc, LevelState>, HasGameRef<PullUpGame> {
  /// item => current duration
  final void Function(ItemEffect effect, double duration) onNewState;

  EffectsController({
    required this.onNewState,
  });

  final Map<ItemEffect, double> _current = {};
  final Map<ItemEffect, TimerComponent> _timers = {};

  List<ItemEffect> get effectsInProgress => _timers.keys.toList();

  void addEffect(ItemEffect effect, double duration) {
    if (effect == ItemEffect.speedUp &&
        effectsInProgress.contains(ItemEffect.slow)) {
      _timers[ItemEffect.slow]?.timer.stop();
      _timers.remove(ItemEffect.slow);
      _current.remove(ItemEffect.slow);
      _stopEffect(ItemEffect.slow);
      onNewState(effect, 0);
      return;
    }
    if (effect == ItemEffect.slow &&
        effectsInProgress.contains(ItemEffect.speedUp)) {
      _timers[ItemEffect.speedUp]?.timer.stop();
      _timers.remove(ItemEffect.speedUp);
      _current.remove(ItemEffect.speedUp);
      _stopEffect(ItemEffect.speedUp);
      onNewState(effect, 0);
      return;
    }
    if (effectsInProgress.contains(effect)) {
      final newDuration = _current[effect]! + duration;
      onNewState(effect, newDuration);
      _current[effect] = newDuration;
      _timers[effect]?.timer.stop();
      _addNewTimer(effect);
    } else {
      onNewState(effect, duration);
      _current[effect] = duration;
      _addNewTimer(effect);
      _handleEffect(effect);
    }
  }

  void _handleEffect(ItemEffect item) {
    final normaldo = game.grid.normaldo;
    switch (item) {
      case ItemEffect.slowMo:
        bloc.add(LevelEvent.changeSpeed(
          speed: bloc.state.level.speed / 2,
          effects: normaldo.effectsController.effectsInProgress,
        ));
      case ItemEffect.slow:
        normaldo.speedMultiplier = 0.5;
      case ItemEffect.immortality:
        normaldo.immortal = true;
        normaldo.startImmortalityFlick();
      case ItemEffect.disorient:
        game.grid.invertControl();
      case ItemEffect.speedUp:
        normaldo.speedMultiplier = 1.3;
      case ItemEffect.immuneToSlowingItems:
        normaldo.addImmuneTo(
          Items.values.where((e) => e.component() is SlowingItem).toList(),
        );
        normaldo.addSatellite(Items.magicHat);
      case ItemEffect.immuneToAttackingItems:
        normaldo.addImmuneTo(
          Items.values
              .where(
                (e) =>
                    e.component() is AttackingItem ||
                    e.component() is KillingItem,
              )
              .toList(),
        );
        normaldo.addSatellite(Items.caseyMask);
    }
  }

  void _stopEffect(ItemEffect effect) {
    final normaldo = game.grid.normaldo;
    switch (effect) {
      case ItemEffect.slowMo:
        bloc.add(LevelEvent.changeSpeed(
          speed: bloc.state.level.speed * 2,
          effects: normaldo.effectsController.effectsInProgress,
        ));
      case ItemEffect.slow:
        normaldo.speedMultiplier = 1;
      case ItemEffect.immortality:
        normaldo.immortal = false;
        normaldo.stopImmortalityFlick();
      case ItemEffect.disorient:
        game.grid.invertControl();
      case ItemEffect.speedUp:
        normaldo.speedMultiplier = 1;
      case ItemEffect.immuneToSlowingItems:
        normaldo.removeImmuneTo(
          Items.values.where((e) => e.component() is SlowingItem).toList(),
        );
        normaldo.removeSatellite(Items.magicHat);
      case ItemEffect.immuneToAttackingItems:
        normaldo.removeImmuneTo(Items.values
            .where(
              (e) =>
                  e.component() is AttackingItem ||
                  e.component() is KillingItem,
            )
            .toList());
        normaldo.removeSatellite(Items.caseyMask);
    }
  }

  void _addNewTimer(ItemEffect item) {
    final timer = TimerComponent(
      period: 1,
      repeat: true,
      onTick: () {
        final current = _current[item] ?? 0;
        if (current == 0) {
          _timers[item]?.timer.stop();
          _timers.remove(item);
          _current.remove(item);
          _stopEffect(item);
        } else {
          final newDuration = _current[item]! - 1;
          _current[item] = newDuration;
          onNewState(item, newDuration);
        }
      },
    );
    _timers[item] = timer;
    add(timer);
  }
}
