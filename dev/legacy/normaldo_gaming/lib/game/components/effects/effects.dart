import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:normaldo_gaming/game/components/item_component.dart';

mixin Effects {
  Effect fadeInEffect({
    double? duration,
    void Function()? onComplete,
  }) =>
      OpacityEffect.fadeIn(
        EffectController(
          duration: duration ?? 1,
        ),
        onComplete: onComplete,
      );
  Effect fadeOutEffect({
    double? duration,
    void Function()? onComplete,
  }) =>
      OpacityEffect.fadeOut(
        EffectController(
          duration: duration ?? 1,
        ),
        onComplete: onComplete,
      );

  Effect scaleInEffect({
    double? duration,
    void Function()? onComplete,
  }) =>
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(
          duration: duration ?? 0.3,
        ),
        onComplete: onComplete,
      );

  Effect scaleOutEffect({
    double? duration,
    void Function()? onComplete,
  }) =>
      ScaleEffect.to(
        Vector2.all(0),
        EffectController(
          duration: duration ?? 0.3,
        ),
        onComplete: onComplete,
      );

  List<Effect> jumpToEffect({
    required Vector2 position,
    double? duration,
    double? speed,
    void Function()? onComplete,
    bool rotateClockwise = true,
  }) {
    return [
      MoveToEffect(
          position,
          EffectController(
            duration: speed == null ? duration ?? 0.5 : null,
            speed: speed,
          ),
          onComplete: onComplete),
      RotateEffect.by(
          2 * pi * (rotateClockwise ? 1 : -1),
          EffectController(
            duration: duration ?? 0.5,
          ),
          onComplete: onComplete),
    ];
  }

  List<Effect> changeLine(Item item) {
    final linesCentersY = item.game.grid.linesCentersY;
    final itemY = item.position.y.ceil().toDouble();
    final isInBottom = itemY == linesCentersY.last;
    final isInTop = itemY == linesCentersY.first;
    final isInProgress = !linesCentersY.contains(itemY);
    if (isInProgress) return [];

    double nextLineY;
    if (isInTop) {
      nextLineY = linesCentersY[1];
    } else if (isInBottom) {
      nextLineY = linesCentersY[linesCentersY.length - 2];
    } else {
      final nextIndex = Random().nextBool()
          ? linesCentersY.indexOf(itemY) - 1
          : linesCentersY.indexOf(itemY) + 1;
      nextLineY = linesCentersY[nextIndex];
    }

    final nextPosition = Vector2(item.x - item.size.x, nextLineY);

    return jumpToEffect(
      position: nextPosition,
      speed: item.speed,
    );
  }

  Effect flickEffect({int? repeatCount}) {
    final controller = EffectController(
      duration: 0.1,
      reverseDuration: 0.1,
      repeatCount: repeatCount ?? 30,
    );
    return OpacityEffect.to(0, controller);
  }
}
