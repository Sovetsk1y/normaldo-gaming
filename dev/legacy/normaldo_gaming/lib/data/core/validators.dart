import 'package:normaldo_gaming/domain/utils/validator.dart';

final class NicknameValidator extends Validator<String> {
  NicknameValidator(super.input);

  final _regExp = RegExp(r'^[a-zA-Zа-яА-я0-9]{3,16}$');

  @override
  bool validate() {
    return _regExp.hasMatch(input);
  }
}

final class EmailValidator extends Validator<String> {
  EmailValidator(super.input);

  final _regExp = RegExp(r'^\S+@\S+\.\S+$');

  @override
  bool validate() {
    return _regExp.hasMatch(input);
  }
}

final class PasswordValidator extends Validator<String> {
  PasswordValidator(super.input);

  @override
  bool validate() {
    return input.length >= 6;
  }
}
