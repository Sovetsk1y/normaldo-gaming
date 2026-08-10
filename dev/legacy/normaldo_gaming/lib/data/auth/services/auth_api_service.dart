import 'package:chopper/chopper.dart';

part "auth_api_service.chopper.dart";

@ChopperApi(baseUrl: "/auth")
abstract class AuthApiService extends ChopperService {
  static AuthApiService create([ChopperClient? client]) =>
      _$AuthApiService(client);

  @Post(path: '/signup')
  Future<Response> signUp({@Body() required String data});

  @Post(path: '/login')
  Future<Response> signIn({@Body() required String data});
}
