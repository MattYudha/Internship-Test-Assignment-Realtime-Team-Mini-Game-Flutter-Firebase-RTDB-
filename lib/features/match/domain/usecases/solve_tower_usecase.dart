import '../repositories/match_repository.dart';

class SolveTowerUseCase {
  final MatchRepository repository;

  SolveTowerUseCase(this.repository);

  Future<bool> call({
    required String matchId,
    required String teamId,
    required String towerId,
    required String playerId,
    required int movesTaken,
    required int optimalMoves,
  }) async {
    return await repository.solveTower(
      matchId,
      teamId,
      towerId,
      playerId,
      movesTaken,
      optimalMoves,
    );
  }
}
