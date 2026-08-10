import 'dart:convert';

import 'package:chopper/chopper.dart';

class UnexpectedError implements Exception {}

class NetworkException implements Exception {
  const NetworkException(this.statusCode, [this.description]);

  NetworkException.fromResponse(Response response)
      : statusCode = response.statusCode,
        description = '${jsonDecode(response.bodyString)['message']}';

  final int statusCode;
  final String? description;
}
