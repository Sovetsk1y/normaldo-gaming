import 'package:flutter_simple_dependency_injection/injector.dart';
import 'package:normaldo_gaming/application/game_session/cubit/cubit/game_session_cubit.dart';
import 'package:normaldo_gaming/application/level/bloc/level_bloc.dart';
import 'package:normaldo_gaming/application/user/cubit/user_cubit.dart';
import 'package:normaldo_gaming/data/app/ng_audio_impl.dart';
import 'package:normaldo_gaming/domain/app/audio.dart';

final injector = Injector();

void initializeInjector() {
  // Cubits&Blocs
  injector.map<UserCubit>((injector) => UserCubit());
  injector.map<GameSessionCubit>((injector) => GameSessionCubit());
  injector.map<LevelBloc>((injector) => LevelBloc());

  // Audio
  injector.map<NgAudio>(
    (injector) => NgAudioImpl(),
    isSingleton: true,
  );
}
