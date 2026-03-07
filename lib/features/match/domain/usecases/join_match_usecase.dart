import '../../domain/repositories/match_repository.dart';
import '../../domain/entities/join_match_result.dart';

class JoinMatchUseCase {
  final MatchRepository repository;
  
  JoinMatchUseCase(this.repository);
  
  Future<JoinMatchResult> call(String playerId, String displayName) async {
    return await repository.joinMatch(playerId, displayName);
  }
}
