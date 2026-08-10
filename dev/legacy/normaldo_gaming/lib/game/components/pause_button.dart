import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_bloc/flame_bloc.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/data/pull_up_game/mixins/has_audio.dart';
import 'package:normaldo_gaming/domain/app/audio_pools.dart';
import 'package:normaldo_gaming/game/utils/overlays.dart';

class PauseButton extends SpriteComponent
    with
        TapCallbacks,
        FlameBlocReader<GameSessionCubit, GameSessionState>,
        HasGameRef,
        HasNgAudio {
  PauseButton() : super(size: Vector2(70, 70));
  @override
  Future<void> onLoad() async {
    super.onLoad();

    sprite = await Sprite.load('pause.png');

    await add(
      FlameBlocListener<GameSessionCubit, GameSessionState>(
          listenWhen: (previousState, newState) =>
              previousState.paused != newState.paused,
          onNewState: (state) {
            if (state.paused) {
              gameRef.pauseEngine();
              audio.pauseAssetBgm();
              gameRef.overlays.add(Overlays.pauseMenu.name);
            } else {
              gameRef.resumeEngine();
              audio.resumeAssetBgm();
              gameRef.overlays.remove(Overlays.pauseMenu.name);
            }
          }),
    );
  }

  @override
  bool onTapDown(TapDownEvent event) {
    audio.playMenuSfx(MenuSfx.button);
    bloc.togglePause();
    return true;
  }
}
