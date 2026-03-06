import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/tower.dart';
import '../../domain/repositories/match_repository.dart';

class MatchRepositoryImpl implements MatchRepository {
  final FirebaseDatabase _db;
  
  MatchRepositoryImpl({FirebaseDatabase? db}) : _db = db ?? FirebaseDatabase.instance;

  DatabaseReference _matchRef(String matchId) => _db.ref('matches/$matchId');

  @override
  Stream<MatchData?> streamMatch(String matchId) {
    return _matchRef(matchId).onValue.map((event) {
      if (!event.snapshot.exists) return null;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return MatchData.fromJson(matchId, data);
    });
  }

  @override
  Future<bool> claimTower(String matchId, String teamId, String towerId, String playerId) async {
    final towerRef = _matchRef(matchId).child('teams/$teamId/towers/$towerId');
    
    try {
      final TransactionResult result = await towerRef.runTransaction((Object? currentData) {
        if (currentData == null) {
          return Transaction.abort();
        }
        
        Map<String, dynamic> towerData = Map<String, dynamic>.from(currentData as Map);
        final state = towerData['state'];
        final currentClaimExp = towerData['claimExpiresAt'] as int?;
        final now = DateTime.now().millisecondsSinceEpoch;

        // Can claim if available OR claim is expired
        if (state == 'available' || (state == 'claimed' && currentClaimExp != null && currentClaimExp < now)) {
          towerData['state'] = 'claimed';
          towerData['claimedBy'] = playerId;
          towerData['claimExpiresAt'] = now + 15000; // 15 seconds from now
          return Transaction.success(towerData);
        }
        
        return Transaction.abort();
      });
      
      return result.committed;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> solveTower(String matchId, String teamId, String towerId, String playerId, int movesTaken, int optimalMoves) async {
    final towerRef = _matchRef(matchId).child('teams/$teamId/towers/$towerId');
    final matchRef = _matchRef(matchId);

    try {
      // 1. Transaction to solve the tower
      final TransactionResult towerResult = await towerRef.runTransaction((Object? currentData) {
        if (currentData == null) return Transaction.abort();
        
        Map<String, dynamic> towerData = Map<String, dynamic>.from(currentData as Map);
        final state = towerData['state'];
        final claimedBy = towerData['claimedBy'];
        final currentClaimExp = towerData['claimExpiresAt'] as int?;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (state == 'claimed' && claimedBy == playerId && (currentClaimExp != null && currentClaimExp >= now)) {
          towerData['state'] = 'solved';
          towerData['solvedBy'] = playerId;
          towerData['movesTaken'] = movesTaken;
          towerData['optimalMoves'] = optimalMoves;
          return Transaction.success(towerData);
        }
        return Transaction.abort();
      });

      if (!towerResult.committed) return false;

      // 2. Atomic increment of score (fire and forget)
      // Since it's atomic, we don't need a heavy local-device transaction.
      matchRef.child('teams/$teamId/score').set(ServerValue.increment(1));

      // 3. Increment Player Stats
      matchRef.child('players/$playerId/stats/towersSolved').set(ServerValue.increment(1));
      matchRef.child('players/$playerId/stats/totalMoves').set(ServerValue.increment(movesTaken));

      // 4. Deterministic regeneration
      // Increment poolIndex via Transaction to get the exact new index without race condition
      final String poolIndexKey = teamId == 'teamA' ? 'poolIndexA' : 'poolIndexB';
      final poolIndexRef = matchRef.child('meta/$poolIndexKey');
      
      int newIndex = -1;
      final TransactionResult poolResult = await poolIndexRef.runTransaction((Object? currentData) {
        int currentVal = (currentData as int?) ?? 0;
        newIndex = currentVal + 1;
        return Transaction.success(newIndex);
      });

      if (poolResult.committed && newIndex != -1) {
        // Fetch new target value from the pool
        final poolSnapshot = await matchRef.child('meta/towerPool/$newIndex').get();
        if (poolSnapshot.exists) {
          final int newStartValue = (poolSnapshot.value as int?) ?? 10;
          
          // Reset the tower slot with the new value so the grid is repopulated
          await towerRef.set({
            'startValue': newStartValue,
            'state': 'available',
            'claimedBy': null,
            'claimExpiresAt': null,
            'solvedBy': null,
            'movesTaken': null,
            'optimalMoves': null,
          });
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> releaseTower(String matchId, String teamId, String towerId) async {
    // Only release if it hasn't been solved (best effort)
    final towerRef = _matchRef(matchId).child('teams/$teamId/towers/$towerId');
    final snapshot = await towerRef.child('state').get();
    if (snapshot.value == 'claimed') {
      await towerRef.update({
        'state': 'available',
        'claimedBy': null,
        'claimExpiresAt': null,
      });
    }
  }

  @override
  Future<void> updateHeartbeat(String matchId, String playerId) async {
    await _matchRef(matchId).child('players/$playerId/lastSeenAt').set(ServerValue.timestamp);
  }

  @override
  Future<void> cleanupExpiredClaims(String matchId, String teamId) async {
    // Best effort cleanup logic to force UI changes locally when a user is AFK
    // Note: To be secure it must happen via transactions, but simple updates might suffice for UI.
    // However, thanks to the lazy validation, explicit backend cleanup isn't strictly necessary,
    // as any active player can claim expired towers.
  }
}
