import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/data/core/validators.dart';
import 'package:normaldo_gaming/domain/auth/auth_repository.dart';
import 'package:normaldo_gaming/domain/utils/validator.dart';

part 'sign_up_state.dart';
part 'sign_up_cubit.freezed.dart';

class SignUpCubit extends Cubit<SignUpState> {
  SignUpCubit(this._authRepository) : super(SignUpState.initial());

  final AuthRepository _authRepository;

  void changeNickname(String nickname) {
    emit(state.copyWith(nickname: NicknameValidator(nickname)));
  }

  void changeEmail(String email) {
    emit(state.copyWith(email: EmailValidator(email)));
  }

  void changePassword(String password) {
    emit(state.copyWith(password: PasswordValidator(password)));
  }

  void changeRepeatPassword(String password) {
    emit(state.copyWith(repeatPassword: PasswordValidator(password)));
  }

  Future<bool> signUp() async {
    if (!state.validated) return false;
    try {
      await _authRepository.signUp(
        email: state.email.input,
        nickname: state.nickname.input,
        password: state.password.input,
      );
      return true;
    } on NetworkException catch (e) {
      emit(state.copyWith(failure: e));
      emit(state.copyWith(failure: null));
      return false;
    } catch (e) {
      emit(state.copyWith(failure: NetworkException(0, e.toString())));
      emit(state.copyWith(failure: null));
      return false;
    }
  }
}
