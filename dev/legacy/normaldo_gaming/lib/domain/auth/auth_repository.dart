abstract interface class AuthRepository {
  Future<String?> get authToken;

  Future<void> signUp({
    required String email,
    required String nickname,
    required String password,
  });

  Future<void> signIn({
    required String email,
    required String password,
  });

  Future<void> logout();
}
