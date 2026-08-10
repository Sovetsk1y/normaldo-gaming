import 'dart:async';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';

mixin ChangeLineEffect on Item {
  final _random = Random();
  bool _lineChanged = false;
  bool get lineChanged => _lineChanged;

  late final double _nextY;

  void changeLine() {
    _lineChanged = true;
    _lineChanged = true;
    add(MoveEffect.to(
        Vector2(x - 100, _nextY),
        EffectController(
          speed: speed,
        ), onComplete: () {
      _lineChanged = false;
    }));
  }

  @override
  FutureOr<void> onLoad() {
    _nextY = _getNextY();
    var changeLineTime = _random.nextInt(2) + 0.5 + _random.nextDouble();
    add(RotateEffect.to(
        _nextY < y ? 0.35 : -0.35,
        EffectController(
          duration: changeLineTime,
          reverseDuration: 1,
        )));
    return super.onLoad();
  }

  double _getNextY() {
    final linesCentersY = game.grid.linesCentersY;
    final isInBottom = y == linesCentersY.last;
    final isInTop = y == linesCentersY.first;
    double nextLineY;
    if (isInTop) {
      nextLineY = linesCentersY[1];
    } else if (isInBottom) {
      nextLineY = linesCentersY[linesCentersY.length - 2];
    } else {
      final nextIndex = _random.nextBool()
          ? linesCentersY.indexOf(y) - 1
          : linesCentersY.indexOf(y) + 1;
      nextLineY = linesCentersY[nextIndex];
    }
    return nextLineY;
  }
}
