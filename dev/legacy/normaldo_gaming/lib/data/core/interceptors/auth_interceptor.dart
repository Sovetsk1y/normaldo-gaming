import 'dart:async';
import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/data/auth/services/auth_local_storage.dart';

class AuthInterceptor implements Interceptor {
  const AuthInterceptor(this._authLocalStorage);

  final AuthLocalStorage _authLocalStorage;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
      Chain<BodyType> chain) async {
    final response = await chain.proceed(chain.request);
    if (!response.isSuccessful) {
      if (response.statusCode == HttpStatus.unauthorized) {
        _authLocalStorage.deleteToken();
      }
      throw NetworkException.fromResponse(response);
    }
    return response;
  }
}
