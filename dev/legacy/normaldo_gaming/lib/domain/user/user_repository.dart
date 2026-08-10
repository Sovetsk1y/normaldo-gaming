import 'entities/user.dart';

abstract interface class UserRepository {
  Future<User> getUserInfo();

  Future<User> updateUser({required User user});
}
