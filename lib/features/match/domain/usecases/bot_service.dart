import 'dart:async';
import 'dart:math';
import '../../domain/entities/match.dart';
import '../../domain/entities/tower.dart';
import '../../domain/usecases/claim_tower_usecase.dart';
import '../../domain/usecases/solve_tower_usecase.dart';
import '../../domain/usecases/bfs_solver.dart';
import 'package:flutter/foundation.dart';

class BotService {
  final ClaimTowerUseCase _claimUseCase;
  final SolveTowerUseCase _solveUseCase;
  
  BotService(this._claimUseCase, this._solveUseCase);

  final List<StreamSubscription> _botSubscriptions = [];
  final Random _random = Random();

  /// Start a bot for a specific team.
  void startBot(String matchId, String teamId, String botId, Stream<MatchData?> matchStream) {
    bool isProcessing = false;

    final sub = matchStream.listen((match) async {
      if (match == null || isProcessing) return;
      
      final team = match.teams[teamId];
      if (team == null) return;

      // Find an available tower
      final availableTowers = team.towers.values.where((t) => t.state == 'available').toList();
      if (availableTowers.isEmpty) return;

      isProcessing = true;

      // JITTER: 1 to 4 seconds to prevent RTDB transaction overload
      final jitterSeconds = 1 + _random.nextInt(4);
      await Future.delayed(Duration(seconds: jitterSeconds));

      // Re-verify availability after jitter
      final towerListAfterJitter = team.towers.values.where((t) => t.state == 'available').toList();
      if (towerListAfterJitter.isEmpty) {
        isProcessing = false;
        return;
      }

      // Pick random available tower
      final Tower targetTower = towerListAfterJitter[_random.nextInt(towerListAfterJitter.length)];

      // Attempt claim
      bool claimSuccess = await _claimUseCase(
        matchId: matchId, 
        teamId: teamId, 
        towerId: targetTower.id, 
        playerId: botId
      );

      if (claimSuccess) {
        // Calculate optimal moves using Isolate to prevent UI freeze
        final optimalMoves = await BfsSolver.getOptimalMoves(targetTower.startValue, match.meta.targetValue);
        
        // JITTER: Simulate human thinking/solving time before submitting solve
        final solveJitter = 2 + _random.nextInt(3);
        await Future.delayed(Duration(seconds: solveJitter));

        await _solveUseCase(
          matchId: matchId, 
          teamId: teamId, 
          towerId: targetTower.id, 
          playerId: botId, 
          movesTaken: optimalMoves, // Bot plays perfectly
          optimalMoves: optimalMoves
        );
      }

      isProcessing = false;
    });

    _botSubscriptions.add(sub);
  }

  void stopAllBots() {
    for (var sub in _botSubscriptions) {
      sub.cancel();
    }
    _botSubscriptions.clear();
  }
}
