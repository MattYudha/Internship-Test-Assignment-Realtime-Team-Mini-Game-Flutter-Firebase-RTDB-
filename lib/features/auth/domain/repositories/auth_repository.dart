abstract class AuthRepository {
  Future<String?> signInAnonymously();
  String? getCurrentUid();
}
