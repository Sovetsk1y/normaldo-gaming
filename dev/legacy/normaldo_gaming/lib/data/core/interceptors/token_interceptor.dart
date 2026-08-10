import 'dart:async';
import 'dart:io';

import 'package:chopper/chopper.dart';
import 'package:normaldo_gaming/data/auth/services/auth_local_storage.dart';

class TokenInterceptor implements Interceptor {
  const TokenInterceptor(this._authLocalStorage);

  final AuthLocalStorage _authLocalStorage;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
      Chain<BodyType> chain) async {
    final request = chain.request;
    if (request.headers['needAuth'] == 'true') {
      final token = await _authLocalStorage.fetchToken();
      if (token == null) return chain.proceed(request);
      final newRequest = request.copyWith(
          headers: request.headers
            ..[HttpHeaders.authorizationHeader] = 'Bearer $token');
      return chain.proceed(newRequest);
    }
    return chain.proceed(request);
  }
}
