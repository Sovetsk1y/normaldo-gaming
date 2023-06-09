part of 'user_cubit.dart';

@freezed
class UserState with _$UserState {
  const factory UserState({
    required User user,
  }) = _UserState;

  factory UserState.initial() => const UserState(
          user: User(
        id: 'no_user',
        name: '',
        highScore: 0,
        dollars: 0,
        level: 0,
        exp: 0,
      ));
}
