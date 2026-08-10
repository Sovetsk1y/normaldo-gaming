import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:normaldo_gaming/domain/auth/auth_repository.dart';

part 'auth_state.dart';
part 'auth_cubit.freezed.dart';

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._authRepository) : super(const AuthState.initial());

  final AuthRepository _authRepository;

  Future<void> auth() async {
    final token = await _authRepository.authToken;
    if (token == null) {
      emit(const AuthState.notAuthorized());
    } else {
      emit(const AuthState.authorized());
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    return auth();
  }
}
