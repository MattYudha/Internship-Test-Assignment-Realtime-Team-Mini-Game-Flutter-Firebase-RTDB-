import 'package:flutter/material.dart';
import '../../domain/entities/tower.dart';
import '../controllers/match_controller.dart';
import 'tower_attempt_modal.dart';
import 'package:get/get.dart';
import 'bouncing_dots_indicator.dart';

class TowerGridWidget extends StatelessWidget {
  final List<Tower> towers;
  final int targetValue;
  final bool isMyTeam;
  final MatchController controller;
  final MaterialColor accentColor;

  const TowerGridWidget({
    super.key,
    required this.towers,
    required this.targetValue,
    required this.isMyTeam,
    required this.controller,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    // Sort logic to keep towers consistent in UI, parse ID numerically to prevent tower_20 coming before tower_3
    final List<Tower> displayTowers = isMyTeam ? controller.visuallyComputedTowers : towers;
    displayTowers.sort((a, b) {
      int idA = int.tryParse(a.id.split('_').last) ?? 0;
      int idB = int.tryParse(b.id.split('_').last) ?? 0;
      return idA.compareTo(idB);
    });

    // Find the last solved tower to place the car uniquely
    final Tower? lastSolvedTower = displayTowers.cast<Tower?>().lastWhere(
      (t) => t!.state == 'solved', 
      orElse: () => null
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Static Target Tower (Leftmost)
        Container(
          width: 50,
          margin: const EdgeInsets.only(right: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Car Icon Placeholder (Only show if no solved towers)
              if (lastSolvedTower == null)
                _buildStrokedCar(24.0)
              else
                const SizedBox(height: 24),
              
              const SizedBox(height: 4),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7E57C2), // Deep Purple
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    border: Border.all(color: const Color(0xFF4527A0), width: 2), // Darker outline
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        '$targetValue',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 2. Dynamic Player Towers (Horizontal List)
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: displayTowers.length,
            itemBuilder: (context, index) {
              final tower = displayTowers[index];
              return _buildTowerBar(context, tower, index, lastSolvedTower);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTowerBar(BuildContext context, Tower tower, int index, Tower? lastSolvedTower) {
    bool isSolved = tower.state == 'solved';
    bool isClaimed = tower.state == 'claimed';
    bool isAvailable = tower.state == 'available';

    // Logarithmic/Clamped Height Calculation
    // Minimum 20% to prevent invisible dots, Maximum 90% to stay below the Target
    double ratio = tower.startValue / targetValue;
    double heightRatio = isSolved ? 1.0 : (ratio).clamp(0.2, 0.9);

    final List<Color> palette = [
      const Color(0xFF66BB6A), // Green
      const Color(0xFFD4E157), // Yellow
      const Color(0xFFAB47BC), // Purple
      const Color(0xFF29B6F6), // Blue
    ];
    final List<Color> borderPalette = [
      const Color(0xFF2E7D32),
      const Color(0xFF9E9D24),
      const Color(0xFF6A1B9A),
      const Color(0xFF0277BD),
    ];

    int colorIndex = index % palette.length;
    Color barColor = palette[colorIndex];
    Color borderColor = borderPalette[colorIndex];

    return GestureDetector(
      onTap: () async {
        if (!isMyTeam) return;
        if (isSolved) return;

        bool success = await controller.handleClaimTower(tower.id);
        if (success) {
          Get.bottomSheet(
            TowerAttemptModal(
              tower: tower,
              targetValue: targetValue,
              controller: controller,
            ),
            isScrollControlled: true,
            isDismissible: false,
            enableDrag: false,
          );
        } else {
          Get.snackbar('Oops', 'Tower is already claimed by someone else',
              snackPosition: SnackPosition.BOTTOM);
        }
      },
      child: Container(
        width: 50,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Column(
            key: ValueKey('${tower.id}_${tower.state}'),
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Top Indicator
              if (isSolved && tower.id == lastSolvedTower?.id)
                _buildStrokedCar(24.0)
              else if (isClaimed)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0, top: 10.0), // Center in 24px space
                  child: BouncingDotsIndicator(color: Colors.lightBlueAccent, size: 6),
                )
              else
                const SizedBox(height: 24),
            
            const SizedBox(height: 4),
            
            // Floating value label
            if (!isSolved) ...[
              Text(
                '${tower.startValue}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  height: 1.0,
                  color: isAvailable ? Colors.green[800] : Colors.purple[800],
                ),
              ),
              const SizedBox(height: 2),
            ],
            // The Bar itself
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: heightRatio,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      border: Border.all(
                        color: borderColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Avatar or '+' Button area at the bottom
            Container(
              height: 40,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF7E57C2), // Purple base
                border: Border.all(color: const Color(0xFF4527A0), width: 2), // Matching stroke
              ),
              child: isAvailable 
                ? const Center(
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.yellow,
                      child: Icon(Icons.add, size: 16, color: Colors.purple),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Placeholder Avatar based on ID hash
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.white,
                        child: Text(
                          _getEmojiForUser(tower.claimedBy ?? tower.solvedBy ?? ''),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getShortName(tower),
                        style: const TextStyle(fontSize: 8, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _getEmojiForUser(String uid) {
    if (uid.isEmpty) return '👤';
    final emojis = ['🐶', '🐱', '🦉', '🦊', '🐻', '🐼', '🐰', '🐯'];
    int index = uid.hashCode.abs() % emojis.length;
    return emojis[index];
  }

  String _getShortName(Tower tower) {
    String uid = tower.claimedBy ?? tower.solvedBy ?? '';
    if (uid.isEmpty) return '';
    return uid.substring(0, 4); // Shorten for the tiny space
  }

  Widget _buildStrokedCar(double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(offset: const Offset(1, 1), child: Icon(Icons.airport_shuttle, size: size, color: Colors.black)),
        Transform.translate(offset: const Offset(-1, 1), child: Icon(Icons.airport_shuttle, size: size, color: Colors.black)),
        Transform.translate(offset: const Offset(1, -1), child: Icon(Icons.airport_shuttle, size: size, color: Colors.black)),
        Transform.translate(offset: const Offset(-1, -1), child: Icon(Icons.airport_shuttle, size: size, color: Colors.black)),
        Transform.translate(offset: const Offset(0, 1.5), child: Icon(Icons.airport_shuttle, size: size, color: Colors.black)),
        Transform.translate(offset: const Offset(0, -1.5), child: Icon(Icons.airport_shuttle, size: size, color: Colors.black)),
        Transform.translate(offset: const Offset(1.5, 0), child: Icon(Icons.airport_shuttle, size: size, color: Colors.black)),
        Transform.translate(offset: const Offset(-1.5, 0), child: Icon(Icons.airport_shuttle, size: size, color: Colors.black)),
        Icon(Icons.airport_shuttle, size: size, color: Colors.white),
      ],
    );
  }
}
