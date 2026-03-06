import '../../domain/repositories/match_repository.dart';

class JoinMatchUseCase {
  final MatchRepository repository;
  
  JoinMatchUseCase(this.repository);
  
  Future<String?> call(String playerId, String displayName) async {
    return await repository.joinMatch(playerId, displayName);
  }
}
