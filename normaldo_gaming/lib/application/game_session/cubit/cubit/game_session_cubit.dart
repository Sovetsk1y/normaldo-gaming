import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/domain/app/audio.dart';
import 'package:normaldo_gaming/injection/injection.dart';

part 'game_session_state.dart';
part 'game_session_cubit.freezed.dart';

class GameSessionCubit extends Cubit<GameSessionState> {
  static const hitRevival = Duration(seconds: 2);
  static const maxLivesCount = 5;

  GameSessionCubit() : super(GameSessionState.initial());

  void eatPizza() {
    emit(state.copyWith(
      score: state.score + 1,
    ));
  }

  void decreaseHunger() {
    if (state.isDead) return;
    final newLives = state.lives - 1;
    if (newLives == 0) {
      die();
      return;
    }
    emit(state.copyWith(lives: newLives));
  }

  void addLives(int count) {
    int lives;
    if (state.lives + count > maxLivesCount) {
      lives = maxLivesCount;
    } else {
      lives = state.lives + count;
    }
    emit(state.copyWith(lives: lives));
  }

  Future<void> takeHit() async {
    if (state.hit || state.isDead) return;
    final newLives = state.lives - 1;
    if (newLives <= 0) {
      die();
      return;
    }
    emit(state.copyWith(lives: newLives, hit: true));
    await Future.delayed(hitRevival);
    emit(state.copyWith(hit: false));
  }

  void resetHit() {
    emit(state.copyWith(hit: false));
  }

  void addDollars(int amount) {
    assert(amount > 0);
    emit(state.copyWith(dollars: state.dollars + 1));
  }

  void togglePause() {
    emit(state.copyWith(paused: !state.paused));
    if (!state.paused) {
      injector.get<NgAudio>().resumeBgm();
    } else {
      injector.get<NgAudio>().pauseBgm();
    }
  }

  void die() {
    emit(state.copyWith(
      isDead: true,
      lives: 0,
    ));
  }

  void setLevel(int level) {
    emit(state.copyWith(level: level));
  }
}
