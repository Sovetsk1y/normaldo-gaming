import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/palette.dart';
import 'package:flutter/material.dart';
import 'package:normaldo_gaming/core/theme.dart';

class NotificationComponent extends TextComponent {
  NotificationComponent({
    required super.text,
    this.color,
    this.fontSize,
  });

  final Color? color;
  final double? fontSize;

  @override
  Future<void> onLoad() async {
    // opacity = 0.0;
    textRenderer = TextPaint(
        style: NGTheme.displaySmall.copyWith(
      color: color?.withOpacity(0.9),
      fontSize: fontSize ?? 12,
    ));
    addAll([
      RemoveEffect(
        delay: 0.58,
      ),
      ScaleEffect.by(Vector2(1.1, 1.1), EffectController(duration: 0.5)),
      MoveEffect.to(
          position + Vector2((-30 + Random().nextInt(60)).toDouble(), -30),
          EffectController(duration: 0.6, onMax: () {}))
    ]);
    return super.onLoad();
  }
}

mixin HasOpacityProvider on Component implements OpacityProvider {
  final Paint _paint = BasicPalette.white.paint();
  final Paint _srcOverPaint = Paint()..blendMode = BlendMode.srcOver;

  @override
  double get opacity => _paint.color.opacity;

  @override
  set opacity(double newOpacity) {
    _paint
      ..color = _paint.color.withOpacity(newOpacity)
      ..blendMode = BlendMode.modulate;
  }

  @override
  void renderTree(Canvas canvas) {
    canvas.saveLayer(null, _srcOverPaint);
    super.renderTree(canvas);
    canvas.drawPaint(_paint);
    canvas.restore();
  }
}
