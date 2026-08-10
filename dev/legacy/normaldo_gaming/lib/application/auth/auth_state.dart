part of 'auth_cubit.dart';

@freezed
class AuthState with _$AuthState {
  const factory AuthState.initial() = _Initial;
  const factory AuthState.authorized() = _Authorized;
  const factory AuthState.notAuthorized() = _NotAuthorized;
}
