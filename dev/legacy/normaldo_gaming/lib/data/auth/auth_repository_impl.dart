import 'dart:convert';

import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/data/auth/services/auth_api_service.dart';
import 'package:normaldo_gaming/data/auth/services/auth_local_storage.dart';
import 'package:normaldo_gaming/domain/auth/auth_repository.dart';

final class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._authService, this._authLocalStorage);

  final AuthApiService _authService;
  final AuthLocalStorage _authLocalStorage;

  bool get loggedIn => _authToken.isNotEmpty;

  @override
  Future<String?> get authToken async {
    if (_authToken.isNotEmpty) return _authToken;
    final token = await _authLocalStorage.fetchToken();
    _authToken = token ?? '';
    if (_authToken.isEmpty) return null;
    return _authToken;
  }

  var _authToken = '';

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _authService.signIn(
        data: jsonEncode({
      'email': email,
      'password': password,
    }));
    if (response.isSuccessful) {
      _authToken = response.body['token'];
      _saveToken();
    } else {
      throw NetworkException.fromResponse(response);
    }
  }

  @override
  Future<void> signUp({
    required String email,
    required String nickname,
    required String password,
  }) async {
    final response = await _authService.signUp(
        data: jsonEncode({
      'nickname': nickname,
      'email': email,
      'password': password,
    }));
    if (response.isSuccessful) {
      _authToken = response.body['token'];
      _saveToken();
    } else {
      throw NetworkException.fromResponse(response);
    }
  }

  Future<void> _saveToken() async {
    return _authLocalStorage.saveToken(_authToken);
  }

  @override
  Future<void> logout() async {
    _authToken = '';
    return _authLocalStorage.deleteToken();
  }
}
