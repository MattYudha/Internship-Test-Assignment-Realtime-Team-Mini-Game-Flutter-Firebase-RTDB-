import '../repositories/match_repository.dart';

class ClaimTowerUseCase {
  final MatchRepository repository;

  ClaimTowerUseCase(this.repository);

  Future<bool> call({
    required String matchId,
    required String teamId,
    required String towerId,
    required String playerId,
  }) async {
    return await repository.claimTower(matchId, teamId, towerId, playerId);
  }
}
