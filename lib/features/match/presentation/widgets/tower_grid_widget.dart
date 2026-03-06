import 'package:flutter/material.dart';
import '../../domain/entities/tower.dart';
import '../controllers/match_controller.dart';
import 'tower_attempt_modal.dart';
import 'package:get/get.dart';

class TowerGridWidget extends StatelessWidget {
  final List<Tower> towers;
  final int targetValue;
  final bool isMyTeam;
  final MatchController controller;
  final Color accentColor;

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
    // Sort logic to keep towers consistent in UI
    final List<Tower> displayTowers = isMyTeam ? controller.visuallyComputedTowers : towers;
    displayTowers.sort((a, b) => a.id.compareTo(b.id));

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 0.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayTowers.length,
      itemBuilder: (context, index) {
        final tower = displayTowers[index];
        return _buildTowerItem(context, tower);
      },
    );
  }

  Widget _buildTowerItem(BuildContext context, Tower tower) {
    Color bgColor;
    Color valueColor;
    String statusText;

    bool isSolved = tower.state == 'solved';
    bool isClaimed = tower.state == 'claimed';

    if (isSolved) {
      bgColor = Colors.grey[300]!;
      valueColor = Colors.grey[600]!;
      statusText = tower.solvedBy != null ? 'Solved' : 'Solved';
    } else if (isClaimed) {
      bgColor = Colors.orange[100]!;
      valueColor = Colors.orange[800]!;
      statusText = 'Claimed';
    } else {
      bgColor = accentColor.withValues(alpha: 0.2);
      valueColor = accentColor[700]!;
      statusText = 'Avail';
    }

    // Calculate height relative to target
    double heightRatio = (tower.startValue / targetValue).clamp(0.1, 1.0);

    return GestureDetector(
      onTap: () async {
        if (!isMyTeam) return;
        if (isSolved) return;

        // Try claim
        bool success = await controller.handleClaimTower(tower.id);
        if (success) {
          // Open Modal
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                height: 120 * heightRatio, // Max height
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  border: Border.all(
                    color: isMyTeam && !isSolved && !isClaimed ? accentColor : Colors.transparent,
                    width: isMyTeam ? 2 : 0,
                  ),
                ),
                child: Center(
                  child: Text(
                    '${tower.startValue}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: valueColor,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSolved ? Colors.grey : (isClaimed ? Colors.orange : Colors.blueGrey),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
