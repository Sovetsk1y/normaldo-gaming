import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/palette.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/core/theme.dart';
import 'package:normaldo_gaming/game/pull_up_game.dart';

class Balance extends PositionComponent
    with FlameBlocListenable<GameSessionCubit, GameSessionState> {
  Balance()
      : super(
          size: Vector2(300, PullUpGame.menuIconSize.y),
          position: Vector2(16, 8),
          anchor: Anchor.topLeft,
        );

  final _amountLabel = TextComponent(
      text: '0',
      textRenderer: TextPaint(
          style: NGTheme.displayLarge.copyWith(
        background: Paint()
          ..color = BasicPalette.black.color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50.0),
      )));

  @override
  void onNewState(GameSessionState state) {
    _amountLabel.text = state.dollars.toString();
  }

  @override
  FutureOr<void> onLoad() async {
    final dollarSprite = SpriteComponent(
      sprite: await Sprite.load('dollar.png'),
      size: PullUpGame.menuIconSize,
    );
    add(dollarSprite..position.y = 4);
    _amountLabel.x = dollarSprite.size.x + 12;
    _amountLabel.y = 12;

    add(_amountLabel);
  }
}
