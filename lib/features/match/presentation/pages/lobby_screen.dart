import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/lobby_controller.dart';

class LobbyScreen extends GetView<LobbyController> {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.lightGreen[50], // Cream background
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Green Header ──────────────────────────────────────────────────
          Container(
            height: 180,
            padding: const EdgeInsets.only(top: 40, left: 24, right: 24, bottom: 24),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const SafeArea(
              bottom: false,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.account_tree_rounded, size: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Tower Challenge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Scrollable Body ──────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Name Field Card ──────────────────────────────────────────
                  Card(
                    elevation: 3,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ENTER NAME',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 1.2)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: controller.playerNameController,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: 'e.g. Alpha Wolf',
                              hintStyle: const TextStyle(color: Colors.black26),
                              prefixIcon: const Icon(Icons.person, color: Colors.black38),
                              filled: true,
                              fillColor: Colors.grey[50],
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Team Selection ─────────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('CHOOSE YOUR TEAM',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 1.2)),
                  ),
                  const SizedBox(height: 12),

                  Obx(() => Row(
                    children: [
                      Expanded(child: _TeamCard(
                        label: 'Team A',
                        emoji: '⚔️',
                        teamColor: Colors.blue[600]!,
                        count: controller.countA.value,
                        isSelected: controller.selectedTeam.value == LobbyTeam.a,
                        isFull: controller.countA.value >= 4,
                        onTap: () => controller.selectedTeam.value = LobbyTeam.a,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _TeamCard(
                        label: 'Team B',
                        emoji: '🛡️',
                        teamColor: Colors.red[500]!,
                        count: controller.countB.value,
                        isSelected: controller.selectedTeam.value == LobbyTeam.b,
                        isFull: controller.countB.value >= 4,
                        onTap: () => controller.selectedTeam.value = LobbyTeam.b,
                      )),
                    ],
                  )),

                  const SizedBox(height: 32),

                  // ── Action Buttons ───────────────────────────────────────────
                  Obx(() {
                    if (controller.isConnecting.value) {
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: Colors.green[600]),
                              const SizedBox(height: 16),
                              Text(
                                controller.loadingMessage.value.isEmpty ? 'Joining...' : controller.loadingMessage.value,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final selected = controller.selectedTeam.value;
                    final isFull = selected == LobbyTeam.a
                        ? controller.countA.value >= 4
                        : selected == LobbyTeam.b
                            ? controller.countB.value >= 4
                            : false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Primary: Join Selected Team
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (selected == null || isFull)
                                ? null
                                : () => controller.findOrHostMatch(preferredTeam: selected),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              disabledBackgroundColor: Colors.grey[300],
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.black38,
                              elevation: (selected == null || isFull) ? 0 : 4,
                              shadowColor: Colors.green.withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              selected == null
                                  ? 'SELECT A TEAM'
                                  : isFull
                                      ? 'TEAM FULL'
                                      : 'JOIN TEAM',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Secondary: Quick Join
                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: () => controller.findOrHostMatch(preferredTeam: null),
                            icon: const Text('⚡', style: TextStyle(fontSize: 18)),
                            label: const Text('QUICK JOIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.amber[800],
                              side: BorderSide(color: Colors.amber[700]!, width: 2),
                              backgroundColor: Colors.amber[50], // Very subtle amber fill
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),

                        // Debug section
                        if (kDebugMode) ...[
                          const SizedBox(height: 48),
                          const Divider(color: Colors.black12),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => controller.debugResetSession(),
                            icon: const Icon(Icons.refresh, color: Colors.orange, size: 18),
                            label: const Text(
                              'Debug: Reset Auth Session',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(foregroundColor: Colors.orange),
                          ),
                        ],
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Team selection card widget
class _TeamCard extends StatelessWidget {
  final String label;
  final String emoji;
  final Color teamColor;
  final int count;
  final bool isSelected;
  final bool isFull;
  final VoidCallback onTap;

  const _TeamCard({
    required this.label,
    required this.emoji,
    required this.teamColor,
    required this.count,
    required this.isSelected,
    required this.isFull,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isFull ? null : onTap,
      child: AnimatedScale( // Micro-animation scaling
        scale: isSelected ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: teamColor.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                )
              else
                const BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
            ],
            border: Border.all(
              color: isSelected ? teamColor : (isFull ? Colors.grey[200]! : Colors.grey[300]!),
              width: isSelected ? 3 : 1,
            ),
          ),
          child: Column(
            children: [
              // Icon Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isFull ? Colors.grey[100] : teamColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 12),
              
              Text(
                label,
                style: TextStyle(
                  color: isFull ? Colors.black38 : Colors.black87,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              
              Text(
                'Players: $count/4',
                style: TextStyle(
                  color: isFull ? Colors.red[600] : Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 12),
              
              // Status Badge
              if (isFull)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text('FULL', style: TextStyle(color: Colors.red[700], fontSize: 11, fontWeight: FontWeight.w800)),
                )
              else if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: teamColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('SELECTED', style: TextStyle(color: teamColor, fontSize: 11, fontWeight: FontWeight.w800)),
                )
              else
                // Dummy spacing when not selected/full so height stays consistent
                const SizedBox(height: 22), 
            ],
          ),
        ),
      ),
    );
  }
}
