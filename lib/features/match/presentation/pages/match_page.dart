import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/match_controller.dart';
import 'widgets/team_arena_widget.dart';

class MatchPage extends GetView<MatchController> {
  const MatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text('Realtime Tower Challenge'),
        actions: [
          Obx(() => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Time: ${controller.remainingSeconds.value ~/ 60}:${(controller.remainingSeconds.value % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          )),
        ],
      ),
      body: SafeArea(
        child: GetBuilder<MatchController>(
          id: 'tower_grid',
          builder: (ctrl) {
            final match = ctrl.liveMatch.value;
            if (match == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final teamA = match.teams['teamA'];
            final teamB = match.teams['teamB'];

            return Column(
              children: [
                // Top half: Team A (Opponent or Self)
                if (teamA != null)
                  Expanded(
                    child: TeamArenaWidget(
                      teamId: 'teamA',
                      teamName: 'Team A (Blue)',
                      teamData: teamA,
                      players: match.players,
                      targetValue: match.meta.targetValue,
                      isMyTeam: ctrl.teamId == 'teamA',
                      controller: ctrl,
                      accentColor: Colors.blueAccent,
                    ),
                  ),
                
                // Divider
                const Divider(height: 4, thickness: 4, color: Colors.black12),

                // Bottom half: Team B (Opponent or Self)
                if (teamB != null)
                  Expanded(
                    child: TeamArenaWidget(
                      teamId: 'teamB',
                      teamName: 'Team B (Cyan)',
                      teamData: teamB,
                      players: match.players,
                      targetValue: match.meta.targetValue,
                      isMyTeam: ctrl.teamId == 'teamB',
                      controller: ctrl,
                      accentColor: Colors.cyan,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
