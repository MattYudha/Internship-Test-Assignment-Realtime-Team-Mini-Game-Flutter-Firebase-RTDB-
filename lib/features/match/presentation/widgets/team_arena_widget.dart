import 'package:flutter/material.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/player.dart';
import '../controllers/match_controller.dart';
import 'tower_grid_widget.dart';
import 'package:get/get.dart';

class TeamArenaWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                  teamName,
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
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Target: $targetValue',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: accentColor[800],
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
                  'Score: ${teamData.score}',
                  key: ValueKey(teamData.score),
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
              final teamPlayers = players.values.where((p) => p.team == teamId).toList();

              return SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: teamPlayers.length,
                  itemBuilder: (context, index) {
                    final player = teamPlayers[index];
                    final isAFK = ctrl.isPlayerAFK(player.uid);
                    
                    // Use alpha colors instead of Opacity widget to prevent Impeller blurry rendering
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(isAFK ? 100 : 255),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isAFK ? Colors.grey : Colors.green),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: isAFK ? Colors.grey : Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            player.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.black.withAlpha(isAFK ? 100 : 255),
                              decoration: isAFK ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (isAFK) ...[
                            const SizedBox(width: 4),
                            Text('💤', style: TextStyle(fontSize: 12, color: Colors.black.withAlpha(100))),
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

          // Towers Grid
          Expanded(
            child: TowerGridWidget(
              towers: teamData.towers.values.toList(),
              targetValue: targetValue,
              isMyTeam: isMyTeam,
              controller: controller,
              accentColor: Colors.purple, // Forcing purple aesthetic for towers
            ),
          ),
        ],
      ),
    );
  }
}
