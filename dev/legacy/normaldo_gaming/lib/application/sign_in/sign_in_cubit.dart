import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/data/core/validators.dart';
import 'package:normaldo_gaming/domain/auth/auth_repository.dart';
import 'package:normaldo_gaming/domain/utils/validator.dart';

part 'sign_in_state.dart';
part 'sign_in_cubit.freezed.dart';

class SignInCubit extends Cubit<SignInState> {
  SignInCubit(this._authRepository) : super(SignInState.initial());

  final AuthRepository _authRepository;

  void changeEmail(String email) {
    emit(state.copyWith(email: EmailValidator(email)));
  }

  void changePassword(String password) {
    emit(state.copyWith(password: PasswordValidator(password)));
  }

  Future<bool> signIn() async {
    if (!state.validated) return false;
    try {
      await _authRepository.signIn(
        email: state.email.input,
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
