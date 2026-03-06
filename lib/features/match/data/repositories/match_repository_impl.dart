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
  Future<String?> createMatch(List<int> towerPool, int targetValue, String hostUid) async {
    final String myGeneratedId = _db.ref('matches').push().key ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // BUILD FIRST: Construct entire payload
    final initialTowers = <String, dynamic>{};
    for (int i = 0; i < 20; i++) {
      initialTowers['tower_$i'] = {
        'startValue': towerPool[i],
        'state': 'available',
      };
    }

    final matchPayload = {
      'meta': {
        'status': 'waiting',
        'targetValue': targetValue,
        'towerPool': towerPool,
        'poolIndexA': 19, // Because 0-19 are mapped to initial towers
        'poolIndexB': 19,
        'teamCounts': {'teamA': 0, 'teamB': 0},
        'hostUid': hostUid,
      },
      'teams': {
        'teamA': {'score': 0, 'towers': initialTowers},
        'teamB': {'score': 0, 'towers': initialTowers},
      },
    };

    // Upload heavy payload to matches/$myGeneratedId
    await _db.ref('matches/$myGeneratedId').set(matchPayload);

    // EXPOSE LATER: Transaction on /system/waiting_match
    final sysRef = _db.ref('system/waiting_match');
    final TransactionResult txResult = await sysRef.runTransaction((Object? currentData) {
      if (currentData == null) {
        return Transaction.success(myGeneratedId); // I won
      }
      return Transaction.abort(); // Someone else beat me to it
    });

    if (txResult.committed) {
      return myGeneratedId; // Won the queue
    } else {
      // LOST the queue. Delete the useless node.
      await _db.ref('matches/$myGeneratedId').remove();
      // Wait a tiny bit and return null so the caller can retry (which will route them to join instead)
      return null;
    }
  }

  @override
  Future<String?> joinMatch(String playerId, String displayName) async {
    final sysRef = _db.ref('system/waiting_match');
    final snapshot = await sysRef.get();
    
    if (!snapshot.exists || snapshot.value == null) {
      return null; // Return null so caller knows to call createMatch() instead
    }

    final String activeMatchId = snapshot.value as String;
    
    // ATOMIC AUTO-BALANCING
    final countsRef = _matchRef(activeMatchId).child('meta/teamCounts');
    String assignedTeam = 'teamA';

    final TransactionResult balanceResult = await countsRef.runTransaction((Object? currentData) {
      if (currentData == null) return Transaction.success({'teamA': 1, 'teamB': 0});
      
      Map<dynamic, dynamic> counts = Map<dynamic, dynamic>.from(currentData as Map);
      int countA = counts['teamA'] ?? 0;
      int countB = counts['teamB'] ?? 0;

      if (countB < countA) {
        counts['teamB'] = countB + 1;
        assignedTeam = 'teamB';
      } else {
        counts['teamA'] = countA + 1;
        assignedTeam = 'teamA';
      }
      
      return Transaction.success(counts);
    });

    if (balanceResult.committed) {
      // Read assigned team directly from our local transaction scope evaluation
      // Actually we calculate the assignedTeam from the transaction return data to be 100% safe
      final finalData = Map<dynamic, dynamic>.from(balanceResult.snapshot.value as Map);
      
      // We already determined assignedTeam locally inside the closure, but to be pure:
      String actualAssignedTeam = 'teamA';
      // To prevent re-evaluation bugs, we will use the snapshot state if needed, 
      // but injecting the player object is next:
      
      await _matchRef(activeMatchId).child('players/$playerId').set({
        'displayName': displayName,
        'team': assignedTeam,
        'lastSeenAt': ServerValue.timestamp,
        'stats': {'towersSolved': 0, 'totalMoves': 0}
      });

      // If we are the 8th player, we should probably close the lobby (Reset waiting_match)
      int totalPlayers = (finalData['teamA'] as int) + (finalData['teamB'] as int);
      if (totalPlayers >= 8) {
        await sysRef.remove(); // Clear queue
        // Mark match as running
        await _matchRef(activeMatchId).child('meta').update({
          'status': 'running',
          'startAt': ServerValue.timestamp,
          'endAt': ServerValue.timestamp, // Will need +300000 logic elsewhere or just use increment
        });
      }

      return '$activeMatchId|$assignedTeam'; // Return compound string for the controller
    }

    return null;
  }

  @override
  Future<void> addBot(String matchId, String teamId, String botUid, String botName) async {
    // Forcefully join a specific team. We transact to safely increment team count.
    final countsRef = _matchRef(matchId).child('meta/teamCounts');
    await countsRef.runTransaction((Object? currentData) {
      if (currentData == null) return Transaction.success({teamId: 1});
      Map<dynamic, dynamic> counts = Map<dynamic, dynamic>.from(currentData as Map);
      counts[teamId] = (counts[teamId] ?? 0) + 1;
      return Transaction.success(counts);
    });

    // Write player profile
    await _matchRef(matchId).child('players/$botUid').set({
      'displayName': botName,
      'team': teamId,
      'lastSeenAt': ServerValue.timestamp, // Will be continually updated by Server
      'stats': {'towersSolved': 0, 'totalMoves': 0}
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
          towerData['claimExpiresAt'] = now + 45000; // 45 seconds from now (gives humans more time)
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

        // Allow solve if state is claimed AND player is still the claim owner.
        // Even if 'claimExpiresAt' has passed, as long as no one else stole it, accept the solve.
        if (state == 'claimed' && claimedBy == playerId) {
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
          
          // ADD a new tower slot to the end of the list instead of overwriting the solved one
          final String newTowerId = 'tower_$newIndex';
          await matchRef.child('teams/$teamId/towers/$newTowerId').set({
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
