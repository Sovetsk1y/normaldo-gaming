import 'dart:convert';

import 'package:normaldo_gaming/core/errors.dart';
import 'package:normaldo_gaming/data/user/models/user_model.dart';
import 'package:normaldo_gaming/data/user/services/user_api_service.dart';
import 'package:normaldo_gaming/domain/user/entities/user.dart';
import 'package:normaldo_gaming/domain/user/user_repository.dart';

final class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl(this._userApiService);

  final UserApiService _userApiService;
  @override
  Future<User> getUserInfo() async {
    final response = await _userApiService.getUser();
    if (!response.isSuccessful) {
      throw NetworkException.fromResponse(response);
    }
    final userJson = response.body['user'];
    return UserModel(
      id: userJson['_id'] as String,
      name: userJson['nickname'] as String,
      dollars: userJson['dollars'] as int,
      highScore: userJson['highScore'] as int,
      level: userJson['level'] as int,
      exp: userJson['experience'] as int,
      extraLives: userJson['extraLives'] as int,
      totalPizzas: 0,
      mySkins: [],
    ).toEntity();
  }

  @override
  Future<User> updateUser({required User user}) async {
    final response = await _userApiService.updateUser(
        data: jsonEncode({
      'updates': {
        'dollars': user.dollars,
        'experience': user.exp,
        'level': user.level,
        'extraLives': user.extraLives,
        'highScore': user.highScore,
        'totalPizzas': user.totalPizzas,
      }
    }));
    return _userModelFromJson(response.body['user']).toEntity();
  }

  UserModel _userModelFromJson(Map<String, dynamic> json) => UserModel(
        id: json['_id'] as String,
        name: json['nickname'] as String,
        dollars: json['dollars'] as int,
        highScore: json['highScore'] as int,
        level: json['level'] as int,
        exp: json['experience'] as int,
        extraLives: json['extraLives'] as int,
        totalPizzas: 0,
        mySkins: [],
      );
}
