import '../entities/match.dart';
import '../entities/join_match_result.dart';

abstract class MatchRepository {
  /// Create a complete match node optimistically
  Future<String?> createMatch(List<int> towerPool, int targetValue, String hostUid);

  /// Join a match by UID, handles auto-balancing via teamCounts transaction
  Future<JoinMatchResult> joinMatch(String playerId, String displayName);

  /// Removes a player cleanly (used for Debug Session Reset to prevent ghost players)
  Future<void> debugCleanupGhostPlayer(String playerId);

  /// Add a bot directly to a specific team
  Future<void> addBot(String matchId, String teamId, String botUid, String botName);

  /// Stream the live match data
  Stream<MatchData?> streamMatch(String matchId);
  
  /// Claim an available tower
  Future<bool> claimTower(String matchId, String teamId, String towerId, String playerId);
  
  /// End the match and announce final results
  Future<void> endMatch(String matchId);
  
  /// Solve a tower, atomically update team score, and deterministically replace the tower
  Future<bool> solveTower(String matchId, String teamId, String towerId, String playerId, int movesTaken, int optimalMoves);
  
  /// Release a claimed tower explicitly 
  Future<void> releaseTower(String matchId, String teamId, String towerId);
  
  /// Update player's heartbeat
  Future<void> updateHeartbeat(String matchId, String playerId);
  
  /// Auto-release towers that belong to AFK players or expired claims
  Future<void> cleanupExpiredClaims(String matchId, String teamId);

  /// Force start a match without requiring 8 players (for testing/debug)
  Future<void> forceStartMatch(String matchId);

  /// Reset the system/waiting_match node so a fresh match can be created
  Future<void> resetWaitingMatch();

  /// Server time offset for synchronized time across widgets
  int get serverTimeOffset;
}
