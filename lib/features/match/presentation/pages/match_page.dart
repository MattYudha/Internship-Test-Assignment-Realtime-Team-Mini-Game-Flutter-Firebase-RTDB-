import 'package:flutter/foundation.dart';
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Lobby',
          onPressed: () {
            Get.dialog(
              AlertDialog(
                title: const Text('Leave Match?'),
                content: const Text('Are you sure you want to leave and go back to the lobby?'),
                actions: [
                  TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () {
                      Get.back(); // Close dialog
                      controller.forceEndAndReset();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Leave', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          // Timer display
          Obx(() => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Time: ${controller.remainingSeconds.value ~/ 60}:${(controller.remainingSeconds.value % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          )),

          // Bot Panel button — visible in debug mode OR for host
          Obx(() {
            if ((controller.isHost || kDebugMode) && controller.botService != null) {
              return IconButton(
                icon: const Icon(Icons.adb),
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

          // Force Start button (only when waiting)
          Obx(() {
            if (controller.isWaiting) {
              return IconButton(
                icon: const Icon(Icons.flash_on, color: Colors.amber),
                tooltip: 'Force Start Match',
                onPressed: () {
                  Get.dialog(
                    AlertDialog(
                      title: const Text('Force Start?'),
                      content: const Text('Start the match now without waiting for 8 players?'),
                      actions: [
                        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            Get.back();
                            controller.forceStartMatch();
                          },
                          child: const Text('Start Now ⚡'),
                        ),
                      ],
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          }),

          // End Game button (only when running)
          Obx(() {
            if (controller.isRunning) {
              return IconButton(
                icon: const Icon(Icons.stop_circle, color: Colors.red),
                tooltip: 'End Game',
                onPressed: () {
                  Get.dialog(
                    AlertDialog(
                      title: const Text('End Game?'),
                      content: const Text('This will end the match for all players and reset everything.'),
                      actions: [
                        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () {
                            Get.back();
                            controller.forceEndAndReset();
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('End Game', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
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
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF81C784), // Light Green (Target Arena color)
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF4CAF50), width: 4),
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
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias, // Fix for Impeller blurry rendering
                  child: Stack(
                    children: [
                      // Main game content
                      Column(
                        children: [
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
                          
                          const Divider(height: 4, thickness: 4, color: Colors.black12),

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

                      // "Waiting for Players" overlay (Prof's Step 3)
                      if (ctrl.isWaiting)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.hourglass_top, size: 64, color: Colors.white),
                                const SizedBox(height: 16),
                                const Text(
                                  'Waiting for Players...',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Obx(() => Text(
                                  '${ctrl.liveMatch.value?.players.length ?? 0} / 8 players joined',
                                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                                )),
                                const SizedBox(height: 24),
                                const Text(
                                  'Add bots with 🤖 or tap ⚡ to force start',
                                  style: TextStyle(fontSize: 14, color: Colors.orangeAccent),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
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
