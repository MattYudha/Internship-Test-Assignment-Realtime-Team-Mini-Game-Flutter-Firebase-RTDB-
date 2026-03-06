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
  final Color accentColor;

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
      color: isMyTeam ? const Color(0xFFE8F5E9) : const Color(0xFFF1F8E9), // Pale Greens
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Team Name, Target, Score
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                teamName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Target: $targetValue',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: accentColor[800],
                  ),
                ),
              ),
              Text(
                'Score: ${teamData.score}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          
          const SizedBox(height: 8),

          // Player Roster List with Active AFK Evaluation (Tied to _uiRefreshTimer)
          GetBuilder<MatchController>(
            id: 'tower_grid',
            builder: (ctrl) {
              final teamPlayers = players.values.where((p) => p.team == teamId).toList();
              final now = DateTime.now().millisecondsSinceEpoch;

              return SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: teamPlayers.length,
                  itemBuilder: (context, index) {
                    final player = teamPlayers[index];
                    final isAFK = (now - player.lastSeenAt) > 30000;
                    
                    return Opacity(
                      opacity: isAFK ? 0.4 : 1.0,
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                                decoration: isAFK ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            if (isAFK) ...[
                              const SizedBox(width: 4),
                              const Text('💤', style: TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
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
