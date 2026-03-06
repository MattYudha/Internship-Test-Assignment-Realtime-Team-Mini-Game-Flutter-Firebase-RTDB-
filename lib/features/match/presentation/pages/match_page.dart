import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/match_controller.dart';
import '../widgets/team_arena_widget.dart';
import '../widgets/debug_bot_panel.dart';

class MatchPage extends GetView<MatchController> {
  const MatchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Obx(() {
            if (controller.isHost && controller.botService != null) {
              return IconButton(
                icon: const Icon(Icons.adb), // Bot/Debug icon
                tooltip: 'Simulate Bots',
                onPressed: () {
                  Get.bottomSheet(
                    DebugBotPanel(botService: controller.botService!),
                    isScrollControlled: true,
                  );
                },
              );
            }
            return const SizedBox.shrink();
          }),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF81C784), // Light Green (Target Arena color)
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF4CAF50), width: 4), // Darker green border
            ),
            child: GetBuilder<MatchController>(
              id: 'tower_grid',
              builder: (ctrl) {
                final match = ctrl.liveMatch.value;
                if (match == null) {
                  return const Center(child: CircularProgressIndicator());
                }

                final teamA = match.teams['teamA'];
                final teamB = match.teams['teamB'];

                return ClipRRect(
                  borderRadius: BorderRadius.circular(20), // Clip content inside border
                  child: Column(
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
                            accentColor: Colors.blue,
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
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
