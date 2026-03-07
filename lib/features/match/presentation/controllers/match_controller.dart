import 'dart:async';
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

  String get currentUid => _authRepo.getCurrentUid() ?? '';
  bool get isHost => liveMatch.value?.meta.hostUid == currentUid;

  @override
  void onInit() {
    super.onInit();
    botService = BotService(_matchRepo, matchId);
    _startMatchStream();
    _startHeartbeat();
    _startUiRefreshTimer();
  }

  void _startMatchStream() {
    _matchSubscription = _matchRepo.streamMatch(matchId).listen((data) {
      liveMatch.value = data;
      if (data != null) botService?.updateMatchState(data);
      _updateCountdown(data);
    });
  }

  void _updateCountdown(MatchData? data) {
    if (data?.meta.endAt != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final diff = data!.meta.endAt! - now;
      remainingSeconds.value = diff > 0 ? (diff / 1000).floor() : 0;
      
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (remainingSeconds.value > 0) {
          remainingSeconds.value--;
        } else {
          timer.cancel();
          
          // Prof Feedback: Detect if Cloud Function failed to run
          if (liveMatch.value?.meta.status == 'running') {
            // Delay slightly to give backend a chance
            Future.delayed(const Duration(seconds: 2), () {
              if (liveMatch.value?.meta.status == 'running') {
                Get.snackbar(
                  'Backend Warning',
                  'Match lifecycle automation appears offline (Functions emulator / backend not responding).',
                  backgroundColor: Colors.orange[300],
                  colorText: Colors.black87,
                  duration: const Duration(seconds: 8), // Longer duration so it's readable
                  isDismissible: true,
                );
              }
            });
          }
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
    // Proactively refresh UI every second to check if any claim expired
    _uiRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      update(['tower_grid']);
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

    final now = DateTime.now().millisecondsSinceEpoch;
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
}
