import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:get/get.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/player.dart';
import '../../domain/entities/tower.dart';
import '../controllers/match_controller.dart';
import '../flame/tower_challenge_game.dart';
import 'tower_attempt_modal.dart';

class TeamArenaWidget extends StatefulWidget {
  final String teamId;
  final String teamName;
  final Team teamData;
  final Map<String, Player> players;
  final int targetValue;
  final bool isMyTeam;
  final MatchController controller;
  final MaterialColor accentColor;

  const TeamArenaWidget({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.teamData,
    required this.players,
    required this.targetValue,
    required this.isMyTeam,
    required this.controller,
    required this.accentColor,
  });

  @override
  State<TeamArenaWidget> createState() => _TeamArenaWidgetState();
}

class _TeamArenaWidgetState extends State<TeamArenaWidget> {
  final Map<String, SingleTowerGame> _gameCache = {};

  @override
  void dispose() {
    _gameCache.clear();
    super.dispose();
  }

  SingleTowerGame _getOrCreateGame(Tower tower, int index, bool isCarOnTop, int targetValue) {
    if (_gameCache.containsKey(tower.id)) {
      final game = _gameCache[tower.id]!;
      game.updateTower(tower, isCarOnTop);
      return game;
    }
    final game = SingleTowerGame(
      players: widget.players,
      towerId: tower.id,
      tower: tower,
      index: index,
      targetValue: targetValue,
      isTargetTower: false,
      isCarOnTop: isCarOnTop,
      onTowerTapped: _handleTowerTapped,
    );
    _gameCache[tower.id] = game;
    return game;
  }

  SingleTowerGame _getTargetGame(bool isCarOnTop, int targetValue) {
    if (_gameCache.containsKey('target')) {
      final game = _gameCache['target']!;
      game.updateTower(
        Tower(id: 'target', startValue: targetValue, state: 'target', claimedBy: null, claimExpiresAt: null, solvedBy: null, movesTaken: null, optimalMoves: null),
        isCarOnTop
      );
      return game;
    }
    final game = SingleTowerGame(
      players: widget.players,
      towerId: 'target',
      tower: Tower(id: 'target', startValue: targetValue, state: 'target', claimedBy: null, claimExpiresAt: null, solvedBy: null, movesTaken: null, optimalMoves: null),
      index: -1,
      targetValue: targetValue,
      isTargetTower: true,
      isCarOnTop: isCarOnTop,
      onTowerTapped: (_) {},
    );
    _gameCache['target'] = game;
    return game;
  }

  void _handleTowerTapped(String towerId) async {
    if (!widget.isMyTeam) return;

    final towersList = widget.isMyTeam 
        ? widget.controller.visuallyComputedTowers 
        : widget.teamData.towers.values.toList();
        
    final tower = towersList.firstWhere((t) => t.id == towerId, orElse: () => throw Exception('Tower not found'));
    
    if (tower.state == 'solved') return;

    bool success = await widget.controller.handleClaimTower(towerId);
    if (success) {
      Get.bottomSheet(
        TowerAttemptModal(
          tower: tower,
          targetValue: widget.targetValue,
          controller: widget.controller,
        ),
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
      );
    } else {
      Get.snackbar('Oops', 'Tower is already claimed by someone else',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync Flame Data within the render loop
    final towers = widget.isMyTeam 
        ? widget.controller.visuallyComputedTowers 
        : widget.teamData.towers.values.toList();
        
    final displayTowers = List<Tower>.from(towers);
    displayTowers.sort((a, b) {
      int idA = int.tryParse(a.id.split('_').last) ?? 0;
      int idB = int.tryParse(b.id.split('_').last) ?? 0;
      return idA.compareTo(idB);
    });

    Tower? latestSolvedTower;
    for (final t in displayTowers) {
      if (t.state == 'solved') {
        if (latestSolvedTower == null ||
            (t.solvedAt ?? 0) > (latestSolvedTower.solvedAt ?? 0)) {
          latestSolvedTower = t;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.transparent, // Let global MatchPage arena wrapper show through
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Team Name, Target, Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.teamName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.accentColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.accentColor.withAlpha(128)),
                ),
                child: Text(
                  'Target: ${widget.targetValue}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: widget.accentColor[800],
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: CurvedAnimation(parent: animation, curve: Curves.elasticOut),
                    child: child,
                  );
                },
                child: Text(
                  'Score: ${widget.teamData.score}',
                  key: ValueKey(widget.teamData.score),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),

          // Player Roster List with Active AFK Evaluation (Tied to _uiRefreshTimer)
          GetBuilder<MatchController>(
            id: 'player_status', // explicitly listen to player_status for AFK reactivity
            builder: (ctrl) {
              final teamPlayers = widget.players.values.where((p) => p.team == widget.teamId).toList();

              return SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: teamPlayers.length,
                  itemBuilder: (context, index) {
                    final player = teamPlayers[index];
                    final isAFK = ctrl.isPlayerAFK(player.uid);
                    final solved = player.stats.towersSolved;
                    
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isAFK
                          ? Colors.black.withAlpha(30)
                          : Colors.white.withAlpha(230),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAFK ? Colors.grey.shade400 : Colors.green.shade400,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // AFK red dot or person icon
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: isAFK ? Colors.grey : Colors.green[700],
                              ),
                              if (isAFK)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          // Player name
                          Text(
                            player.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isAFK ? Colors.grey : Colors.black87,
                              decoration: isAFK ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          // Towers solved badge
                          if (solved > 0) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade600,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '✓$solved',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          // AFK label
                          if (isAFK) ...[
                            const SizedBox(width: 4),
                            const Text('💤', style: TextStyle(fontSize: 9)),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              );
            }
          ),
          
          const SizedBox(height: 8),

          // Towers Area: Static Target + Scrollable ListView
          Expanded(
            child: Row(
              children: [
                // 1. Static Target Tower (Always visible on the left)
                SizedBox(
                  width: 58, // slightly wider than 50 towerWidth to give padding
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: GameWidget(
                      game: _getTargetGame(latestSolvedTower == null, widget.targetValue),
                    ),
                  ),
                ),
                
                // 2. Dynamic Player Towers (Horizontal List)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: displayTowers.length,
                      itemBuilder: (context, index) {
                        final tower = displayTowers[index];
                        final isCarOnTop = latestSolvedTower?.id == tower.id;
                        return Container(
                          padding: const EdgeInsets.only(right: 8),
                          width: 58, // 50 width + 8 padding
                          child: GameWidget(
                            game: _getOrCreateGame(tower, index, isCarOnTop, widget.targetValue),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
