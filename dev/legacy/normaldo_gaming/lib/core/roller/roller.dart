import 'dart:math';

class EmptyRolls implements Exception {}

final class _Roll<T extends Object> {
  const _Roll(this.roll, this.accumulatedWeight);

  final T roll;
  final double accumulatedWeight;
}

final class Roller<T extends Object> {
  Roller(List<(T roll, double weight)> rolls) {
    for (final roll in rolls) {
      add(roll.$1, roll.$2);
    }
  }

  final List<_Roll<T>> _rolls = [];

  List<T> get items => _rolls.map((e) => e.roll).toList();

  double _accumulatedWeight = 0.0;

  void add(T roll, double weight) {
    _accumulatedWeight += weight;
    _rolls.add(_Roll(roll, _accumulatedWeight));
  }

  T roll() {
    final value = Random().nextDouble() * _accumulatedWeight;
    for (final roll in _rolls) {
      if (roll.accumulatedWeight >= value) {
        return roll.roll;
      }
    }
    throw EmptyRolls();
  }
}
