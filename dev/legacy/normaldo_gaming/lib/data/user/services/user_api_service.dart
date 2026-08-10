import 'package:chopper/chopper.dart';
import 'package:normaldo_gaming/data/core/need_auth_header.dart';

part "user_api_service.chopper.dart";

@ChopperApi(baseUrl: "/user")
abstract class UserApiService extends ChopperService {
  static UserApiService create([ChopperClient? client]) =>
      _$UserApiService(client);

  @Get(path: '/info', headers: needAuthHeader)
  Future<Response> getUser();

  @Put(path: '/updateUser', headers: needAuthHeader)
  Future<Response> updateUser({@Body() required String data});
}
