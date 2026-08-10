part of 'sign_up_cubit.dart';

@freezed
class SignUpState with _$SignUpState {
  const SignUpState._();

  const factory SignUpState({
    required NicknameValidator nickname,
    required EmailValidator email,
    required PasswordValidator password,
    required PasswordValidator repeatPassword,
    NetworkException? failure,
  }) = _SignUpState;

  bool get passwordsMatch => password.input == repeatPassword.input;

  bool get validated =>
      ValidatorConsumer.validate([nickname, email, password, repeatPassword]);

  factory SignUpState.initial() => SignUpState(
        nickname: NicknameValidator(''),
        email: EmailValidator(''),
        password: PasswordValidator(''),
        repeatPassword: PasswordValidator(''),
      );
}
