abstract class AuthRepository {
  Future<String?> signInAnonymously();
  String? getCurrentUid();
  Future<void> signOut();
}
