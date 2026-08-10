import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

class ScoreLabel extends PositionComponent
    with FlameBlocListenable<GameSessionCubit, GameSessionState> {
  ScoreLabel()
      : super(
          size: Vector2(300, PullUpGame.menuIconSize.y),
          position: Vector2(16, 8),
          anchor: Anchor.topLeft,
        );

  final _text = TextComponent(
      textRenderer: TextPaint(
          style: NGTheme.displayLarge.copyWith(
    background: Paint()
      ..color = BasicPalette.black.color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50.0),
  )));

  @override
  FutureOr<void> onLoad() async {
    final pizzaSprite = SpriteComponent(
      sprite: await Sprite.load('pizza.png'),
      size: PullUpGame.menuIconSize,
    );
    add(pizzaSprite..position.y = 4);
    _text.text = '0';
    add(_text
      ..position.x = pizzaSprite.size.x + 12
      ..position.y = 8);
  }

  @override
  void onNewState(GameSessionState state) {
    _text.text = state.score.toString();
  }
}
