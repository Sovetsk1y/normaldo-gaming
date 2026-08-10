part of 'user_cubit.dart';

@freezed
class UserState with _$UserState {
  const factory UserState({
    required User user,
    required bool educated,

    /// passed intro + intro game
    required bool introduced,
    required Skin skin,
    required List<String> activatedPromoCodes,
    NetworkException? failure,
  }) = _UserState;

  factory UserState.initial() => UserState(
        user: User(
          id: 'no_user',
          name: '',
          highScore: 0,
          dollars: 0,
          level: 1,
          exp: 0,
          extraLives: 0,
          totalPizzas: 0,
          mySkins: [
            Skin.basic(),
          ],
        ),
        educated: false,
        introduced: false,
        skin: Skin.basic(),
        activatedPromoCodes: [],
      );
}
