import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/tower.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/entities/join_match_result.dart';

class MatchRepositoryImpl implements MatchRepository {
  final FirebaseDatabase _db;
  int _serverTimeOffset = 0;
  
  MatchRepositoryImpl({FirebaseDatabase? db}) : _db = db ?? FirebaseDatabase.instance {
    _initServerTimeOffset();
  }

  void _initServerTimeOffset() {
    _db.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (event.snapshot.exists) {
        _serverTimeOffset = (event.snapshot.value as num).toInt();
      }
    });
  }

  int get _serverTimeMs => DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

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
  Future<JoinMatchResult> joinMatch(String playerId, String displayName, {String? preferredTeam}) async {
    final sysRef = _db.ref('system/waiting_match');
    final snapshot = await sysRef.get();
    
    if (!snapshot.exists || snapshot.value == null) {
      return const JoinMatchResult(status: JoinMatchStatus.error, message: 'No active match found');
    }

    final String activeMatchId = snapshot.value as String;
    
    // --- 1. Check Match Status ---
    final statusSnap = await _matchRef(activeMatchId).child('meta/status').get();
    final currentStatus = statusSnap.exists ? statusSnap.value as String : 'waiting';
    
    if (currentStatus == 'ended') {
      await sysRef.remove();
      return const JoinMatchResult(status: JoinMatchStatus.error, message: 'Match has ended');
    }

    // --- 2. Reconnect System ---
    final playerSnapshot = await _matchRef(activeMatchId).child('players/$playerId').get();
    if (playerSnapshot.exists) {
      final playerData = Map<dynamic, dynamic>.from(playerSnapshot.value as Map);
      await _matchRef(activeMatchId).child('players/$playerId').update({
        'displayName': displayName,
        'lastSeenAt': ServerValue.timestamp,
      });
      return JoinMatchResult(
        status: JoinMatchStatus.reconnected,
        matchId: activeMatchId,
        teamId: playerData['team'],
      );
    }

    // UID DOES NOT EXIST IN MATCH.
    if (currentStatus == 'running') {
      return const JoinMatchResult(status: JoinMatchStatus.lateJoinRejected, message: 'Match is already running.');
    }

    // --- 3. Atomic Slot Acquisition with preferredTeam support ---
    final countsRef = _matchRef(activeMatchId).child('meta/teamCounts');
    String assignedTeam = '';
    bool isMatchFull = false;
    bool isTeamFull = false;

    final TransactionResult balanceResult = await countsRef.runTransaction((Object? currentData) {
      if (currentData == null) {
        // First player ever, honor preferredTeam or default to A
        final team = preferredTeam ?? 'teamA';
        assignedTeam = team;
        return Transaction.success({team == 'teamA' ? 'teamA' : 'teamB': 1, team == 'teamA' ? 'teamB' : 'teamA': 0});
      }
      
      Map<dynamic, dynamic> counts = Map<dynamic, dynamic>.from(currentData as Map);
      int countA = counts['teamA'] ?? 0;
      int countB = counts['teamB'] ?? 0;

      if (preferredTeam != null) {
        // --- Preferred team path: honor the choice with per-team 4-cap ---
        if (preferredTeam == 'teamA') {
          if (countA >= 4) {
            isTeamFull = true;
            return Transaction.abort();
          }
          counts['teamA'] = countA + 1;
          assignedTeam = 'teamA';
        } else {
          if (countB >= 4) {
            isTeamFull = true;
            return Transaction.abort();
          }
          counts['teamB'] = countB + 1;
          assignedTeam = 'teamB';
        }
      } else {
        // --- Quick Join path: auto-balance with total 8-cap ---
        if (countA + countB >= 8) {
          isMatchFull = true;
          return Transaction.abort();
        }
        if (countB < countA) {
          counts['teamB'] = countB + 1;
          assignedTeam = 'teamB';
        } else {
          counts['teamA'] = countA + 1;
          assignedTeam = 'teamA';
        }
      }
      
      return Transaction.success(counts);
    });

    if (!balanceResult.committed) {
      if (isTeamFull) {
        return JoinMatchResult(
          status: JoinMatchStatus.teamFull,
          message: '${preferredTeam == 'teamA' ? 'Team A' : 'Team B'} is full. Please choose the other team.',
        );
      }
      if (isMatchFull) {
        return const JoinMatchResult(status: JoinMatchStatus.matchFull, message: 'Match is full.');
      }
      return const JoinMatchResult(status: JoinMatchStatus.error, message: 'Failed to join match due to traffic.');
    }

    // Slot secured! Write player node
    final finalData = Map<dynamic, dynamic>.from(balanceResult.snapshot.value as Map);
    Map<String, dynamic> updates = {
      'players/$playerId': {
        'displayName': displayName,
        'team': assignedTeam,
        'lastSeenAt': ServerValue.timestamp,
        'stats': {'towersSolved': 0, 'totalMoves': 0}
      }
    };

    int totalPlayers = (finalData['teamA'] as int) + (finalData['teamB'] as int);
    if (totalPlayers >= 8 && currentStatus != 'running') {
      final now = _serverTimeMs;
      updates['meta/status'] = 'running';
      updates['meta/startAt'] = now;
      updates['meta/endAt'] = now + 300000;
    }

    await _matchRef(activeMatchId).update(updates);

    return JoinMatchResult(
      status: JoinMatchStatus.joined,
      matchId: activeMatchId,
      teamId: assignedTeam,
    );
  }

  @override
  Future<void> debugCleanupGhostPlayer(String playerId) async {
    final sysRef = _db.ref('system/waiting_match');
    final snapshot = await sysRef.get();
    
    if (!snapshot.exists || snapshot.value == null) return;
    final String activeMatchId = snapshot.value as String;
    
    final statusSnap = await _matchRef(activeMatchId).child('meta/status').get();
    final currentStatus = statusSnap.exists ? statusSnap.value as String : 'waiting';
    if (currentStatus != 'waiting') return; // Cannot cleanup from a running match

    final playerRef = _matchRef(activeMatchId).child('players/$playerId');
    final pSnap = await playerRef.get();
    
    if (pSnap.exists) {
      final teamId = (Map<dynamic, dynamic>.from(pSnap.value as Map))['team'] as String?;
      if (teamId != null) {
        // Transactionally decrement the counts
        await _matchRef(activeMatchId).child('meta/teamCounts').runTransaction((Object? currentData) {
          if (currentData == null) return Transaction.abort();
          Map<dynamic, dynamic> counts = Map<dynamic, dynamic>.from(currentData as Map);
          int current = counts[teamId] ?? 0;
          if (current > 0) counts[teamId] = current - 1;
          return Transaction.success(counts);
        });
      }
      // Remove player node
      await playerRef.remove();
    }
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
    
    // Prof's Rule #2: Secure transaction base.
    // In a real production app, this should ALSO be enforced in database.rules.json.
    // Here we ensure the client at least attempts to validate team ownership before spamming.
    
    try {
      final TransactionResult result = await towerRef.runTransaction((Object? currentData) {
        if (currentData == null) {
          return Transaction.abort();
        }
        
        Map<String, dynamic> towerData = Map<String, dynamic>.from(currentData as Map);
        final state = towerData['state'];
        final currentClaimExp = towerData['claimExpiresAt'] as num?;
        final now = _serverTimeMs;

        // Can claim if available OR claim is expired based on EXACT server time
        if (state == 'available' || (state == 'claimed' && currentClaimExp != null && currentClaimExp < now)) {
          towerData['state'] = 'claimed';
          towerData['claimedBy'] = playerId;
          towerData['claimExpiresAt'] = now + 90000; // 90 seconds — enough for human players to solve multi-step towers
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
          towerData['solvedAt'] = ServerValue.timestamp; // Timestamp for car position
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

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error solving tower: $e');
      }
      return false;
    }
  }

  @override
  Future<bool> replaceTower(String matchId, String teamId, String towerId) async {
    try {
      final DatabaseReference matchRef = _db.ref('matches/$matchId');
      final DatabaseReference towerRef = matchRef.child('teams/$teamId/towers/$towerId');

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
          
          // REPLACE the old solved tower slot with a fresh available tower
          // This keeps the total tower count strictly at 20 to prevent FPS drops.
          // By wiping solvedAt, the car icon naturally detaches.
          await towerRef.set({
            'id': towerId,
            'startValue': newStartValue,
            'state': 'available',
            'claimedBy': null,
            'claimExpiresAt': null,
            'solvedBy': null,
            'solvedAt': null,
            'movesTaken': null,
            'optimalMoves': null,
          });
          return true;
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error replacing tower: $e');
      }
      return false;
    }
  }

  @override
  Future<void> releaseTower(String matchId, String teamId, String towerId) async {
    final towerRef = _matchRef(matchId).child('teams/$teamId/towers/$towerId');
    
    // Use transaction to prevent overriding someone else's freshly claimed tower
    try {
      await towerRef.runTransaction((Object? currentData) {
        if (currentData == null) return Transaction.abort();
        
        Map<String, dynamic> towerData = Map<String, dynamic>.from(currentData as Map);
        if (towerData['state'] == 'claimed') {
           towerData['state'] = 'available';
           towerData['claimedBy'] = null;
           towerData['claimExpiresAt'] = null;
           return Transaction.success(towerData);
        }
        return Transaction.abort();
      });
    } catch (e) {
      // Best effort failure handling, do nothing
    }
  }

  @override
  Future<void> endMatch(String matchId) async {
    final statusRef = _matchRef(matchId).child('meta/status');
    
    // Prof's Rule #3: Decentralized Termination (with Jitter)
    // Add a random delay between 0 to 2 seconds to spread out API requests
    // when all 8 clients try to end the match simultaneously.
    final Random random = Random();
    int jitterMs = random.nextInt(2000); 
    await Future.delayed(Duration(milliseconds: jitterMs));
    
    try {
      // The Jitter champion gets to transact the final payload.
      await statusRef.runTransaction((Object? currentData) {
        if (currentData == 'running') {
          return Transaction.success('ended');
        }
        return Transaction.abort(); // Someone beat us during network latency
      });
    } catch(e) {
      // ignore
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

  @override
  Future<void> forceStartMatch(String matchId) async {
    final metaRef = _matchRef(matchId).child('meta');
    
    try {
      await metaRef.runTransaction((Object? currentData) {
        if (currentData == null) return Transaction.abort();
        
        Map<String, dynamic> meta = Map<String, dynamic>.from(currentData as Map);
        
        // Only start if currently waiting
        if (meta['status'] != 'waiting') return Transaction.abort();
        
        final now = _serverTimeMs;
        meta['status'] = 'running';
        meta['startAt'] = now;
        meta['endAt'] = now + 300000; // 5 minutes
        
        return Transaction.success(meta);
      });
    } catch (e) {
      // ignore
    }
  }

  @override
  Future<void> resetWaitingMatch() async {
    await _db.ref('system/waiting_match').remove();
  }

  @override
  int get serverTimeOffset => _serverTimeOffset;
}
