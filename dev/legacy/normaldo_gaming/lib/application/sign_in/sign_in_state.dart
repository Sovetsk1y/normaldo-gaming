part of 'sign_in_cubit.dart';

@freezed
class SignInState with _$SignInState {
  const SignInState._();

  const factory SignInState({
    required EmailValidator email,
    required PasswordValidator password,
    NetworkException? failure,
  }) = _SignInState;

  bool get validated => ValidatorConsumer.validate([
        email,
        password,
      ]);

  factory SignInState.initial() => SignInState(
        email: EmailValidator(''),
        password: PasswordValidator(''),
      );
}
