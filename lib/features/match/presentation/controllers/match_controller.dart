import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/match.dart';
import '../../domain/entities/tower.dart';
import '../../domain/usecases/claim_tower_usecase.dart';
import '../../domain/usecases/solve_tower_usecase.dart';
import '../../domain/usecases/bfs_solver.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/usecases/bot_service.dart';
import 'package:firebase_database/firebase_database.dart';

class MatchController extends GetxController {
  final MatchRepository _matchRepo;
  final AuthRepository _authRepo;
  final ClaimTowerUseCase _claimUseCase;
  final SolveTowerUseCase _solveUseCase;

  final String matchId;
  final String teamId;

  MatchController(
    this._matchRepo,
    this._authRepo,
    this._claimUseCase,
    this._solveUseCase,
    this.matchId,
    this.teamId,
  );

  final Rx<MatchData?> liveMatch = Rx<MatchData?>(null);
  StreamSubscription? _matchSubscription;
  Timer? _heartbeatTimer;
  Timer? _countdownTimer;
  Timer? _uiRefreshTimer; // For proactive AFK visual release

  BotService? botService;

  final RxInt remainingSeconds = 0.obs;
  final RxBool isMatchLocallyEnded = false.obs;

  String get currentUid => _authRepo.getCurrentUid() ?? '';
  bool get isHost => liveMatch.value?.meta.hostUid == currentUid;
  
  // Exact server time fetching via native logic
  int _serverTimeOffset = 0;
  void _initServerTimeOffset() {
    FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (event.snapshot.exists) {
        _serverTimeOffset = (event.snapshot.value as num).toInt();
      }
    });
  }
  int get serverTimeMs => DateTime.now().millisecondsSinceEpoch + _serverTimeOffset;

  @override
  void onInit() {
    super.onInit();
    _initServerTimeOffset();
    botService = BotService(_matchRepo, matchId);
    _startMatchStream();
    _startHeartbeat();
    _startUiRefreshTimer();
    _startAfkPurger();
  }

  void _startMatchStream() {
    _matchSubscription = _matchRepo.streamMatch(matchId).listen((data) {
      liveMatch.value = data;
      if (data != null) botService?.updateMatchState(data);
      _updateCountdown(data);
    });
  }

  void _updateCountdown(MatchData? data) {
    if (data == null) return;
    
    // Status overrider checking actual database structure
    if (data.meta.status == 'ended') {
      isMatchLocallyEnded.value = true;
      remainingSeconds.value = 0;
      _countdownTimer?.cancel();
      return;
    }

    if (data.meta.endAt != null) {
      final now = serverTimeMs;
      final diff = data.meta.endAt! - now;
      remainingSeconds.value = diff > 0 ? (diff / 1000).floor() : 0;
      
      // Prof's Rule #3 Decentralized Termination & Passive Locking
      if (diff <= 0) {
        isMatchLocallyEnded.value = true; 
        // Trigger the backend endMatch transaction. The repository handles Jitter logic!
        _matchRepo.endMatch(matchId); 
      } else {
        isMatchLocallyEnded.value = false;
      }
      
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final currentDiff = data.meta.endAt! - serverTimeMs;
        if (currentDiff > 0) {
          remainingSeconds.value = (currentDiff / 1000).floor();
        } else {
          remainingSeconds.value = 0;
          isMatchLocallyEnded.value = true;
          timer.cancel();
          _matchRepo.endMatch(matchId); 
        }
      });
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (currentUid.isNotEmpty) {
        _matchRepo.updateHeartbeat(matchId, currentUid);
      }
    });
  }

  void _startUiRefreshTimer() {
    // Proactively refresh UI every second to check if any claim expired visually
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      update(['tower_grid']);
    });
  }

  void _startAfkPurger() {
    // Prof's Rule #1: Decentralized Anti-DDoS AFK Purger
    Timer.periodic(const Duration(seconds: 5), (_) async {
      final match = liveMatch.value;
      if (match == null || isMatchLocallyEnded.value) return;

      final now = serverTimeMs;
      final team = match.teams[teamId];
      if (team == null) return;

      for (final tower in team.towers.values) {
        if (tower.state == 'claimed' && tower.claimExpiresAt != null && tower.claimExpiresAt! < now) {
          // JITTER: 0 to 2 seconds delay to avoid 8 clients hitting backend at the same ms
          final jitterDelay = Random().nextInt(2000);
          await Future.delayed(Duration(milliseconds: jitterDelay));
          
          // RE-CHECK strictly because someone else might have cleaned it or claimed it during jitter!
          final currentMatch = liveMatch.value;
          if (currentMatch != null) {
            final currentTower = currentMatch.teams[teamId]?.towers[tower.id];
            if (currentTower != null && currentTower.state == 'claimed' && currentTower.claimExpiresAt! < serverTimeMs) {
              // Confirmed still stale! Send release transaction
              _matchRepo.releaseTower(matchId, teamId, tower.id);
            }
          }
        }
      }
    });
  }

  @override
  void onClose() {
    botService?.stopSimulation();
    _matchSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _countdownTimer?.cancel();
    _uiRefreshTimer?.cancel();
    super.onClose();
  }

  /// Get towers with computed state (converting expired claimed to available visually)
  List<Tower> get visuallyComputedTowers {
    final team = liveMatch.value?.teams[teamId];
    if (team == null) return [];

    final now = serverTimeMs; // Lock to server time
    final towers = team.towers.values.toList();
    
    // Sort by id predictably if needed, or by startValue
    towers.sort((a, b) => a.id.compareTo(b.id));

    return towers.map((t) {
      if (t.state == 'claimed' && t.claimExpiresAt != null && t.claimExpiresAt! < now) {
        // Visually treat as available
        return t.copyWith(state: 'available');
      }
      return t;
    }).toList();
  }

  Future<bool> handleClaimTower(String towerId) async {
    return await _claimUseCase(
      matchId: matchId,
      teamId: teamId,
      towerId: towerId,
      playerId: currentUid,
    );
  }

  Future<bool> handleSolveTower(String towerId, int startValue, int moves) async {
    final target = liveMatch.value?.meta.targetValue ?? 1000;
    
    // Non-blocking BFS optimal moves calculation
    final optimal = await BfsSolver.getOptimalMoves(startValue, target);

    return await _solveUseCase(
      matchId: matchId,
      teamId: teamId,
      towerId: towerId,
      playerId: currentUid,
      movesTaken: moves,
      optimalMoves: optimal,
    );
  }

  Future<void> handleCancelClaim(String towerId) async {
    await _matchRepo.releaseTower(matchId, teamId, towerId);
  }

  /// Force start the match without waiting for 8 players
  Future<void> forceStartMatch() async {
    await _matchRepo.forceStartMatch(matchId);
  }

  /// Force end the match, clean up everything, and navigate back to lobby
  Future<void> forceEndAndReset() async {
    // 1. Stop all bots first
    botService?.stopSimulation();
    
    // 2. Cancel all timers to prevent memory leaks (Prof's Rule)
    _heartbeatTimer?.cancel();
    _countdownTimer?.cancel();
    _uiRefreshTimer?.cancel();
    _matchSubscription?.cancel();

    // 3. End match on Firebase
    await _matchRepo.endMatch(matchId);
    
    // 4. Reset system/waiting_match so new matches can be created
    await _matchRepo.resetWaitingMatch();
    
    // 5. Navigate back to lobby, clearing the entire navigation stack
    Get.offAllNamed('/lobby');
  }

  /// Check if match is in waiting state
  bool get isWaiting => liveMatch.value?.meta.status == 'waiting';
  
  /// Check if match is running
  bool get isRunning => liveMatch.value?.meta.status == 'running';
}
