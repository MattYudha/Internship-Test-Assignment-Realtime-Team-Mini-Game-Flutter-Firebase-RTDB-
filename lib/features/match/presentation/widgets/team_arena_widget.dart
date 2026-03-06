import 'package:flutter/material.dart';
import '../../domain/entities/team.dart';
import '../../domain/entities/player.dart';
import '../controllers/match_controller.dart';
import 'tower_grid_widget.dart';

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
    // Dynamic score calculation
    int solvedCount = teamData.towers.values.where((t) => t.state == 'solved').length;

    return Container(
      padding: const EdgeInsets.all(8.0),
      color: isMyTeam ? Colors.white : const Color(0xFFF0F4F8),
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
                  color: isMyTeam ? Colors.blue[800] : Colors.grey[700],
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
                    color: accentColor[700],
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
          
          // Towers Grid
          Expanded(
            child: TowerGridWidget(
              towers: teamData.towers.values.toList(),
              targetValue: targetValue,
              isMyTeam: isMyTeam,
              controller: controller,
              accentColor: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
