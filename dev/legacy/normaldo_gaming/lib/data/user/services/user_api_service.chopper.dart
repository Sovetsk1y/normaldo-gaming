// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_api_service.dart';

// **************************************************************************
// ChopperGenerator
// **************************************************************************

// ignore_for_file: type=lint
final class _$UserApiService extends UserApiService {
  _$UserApiService([ChopperClient? client]) {
    if (client == null) return;
    this.client = client;
  }

  @override
  final definitionType = UserApiService;

  @override
  Future<Response<dynamic>> getUser() {
    final Uri $url = Uri.parse('/user/info');
    final Map<String, String> $headers = {
      'needAuth': 'true',
    };
    final Request $request = Request(
      'GET',
      $url,
      client.baseUrl,
      headers: $headers,
    );
    return client.send<dynamic, dynamic>($request);
  }

  @override
  Future<Response<dynamic>> updateUser({required String data}) {
    final Uri $url = Uri.parse('/user/updateUser');
    final Map<String, String> $headers = {
      'needAuth': 'true',
    };
    final $body = data;
    final Request $request = Request(
      'PUT',
      $url,
      client.baseUrl,
      body: $body,
      headers: $headers,
    );
    return client.send<dynamic, dynamic>($request);
  }
}
