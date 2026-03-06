import '../entities/match.dart';

abstract class MatchRepository {
  /// Stream the live match data
  Stream<MatchData?> streamMatch(String matchId);
  
  /// Claim an available tower
  Future<bool> claimTower(String matchId, String teamId, String towerId, String playerId);
  
  /// Solve a tower, atomically update team score, and deterministically replace the tower
  Future<bool> solveTower(String matchId, String teamId, String towerId, String playerId, int movesTaken, int optimalMoves);
  
  /// Release a claimed tower explicitly 
  Future<void> releaseTower(String matchId, String teamId, String towerId);
  
  /// Update player's heartbeat
  Future<void> updateHeartbeat(String matchId, String playerId);
  
  /// Auto-release towers that belong to AFK players or expired claims
  Future<void> cleanupExpiredClaims(String matchId, String teamId);
}
