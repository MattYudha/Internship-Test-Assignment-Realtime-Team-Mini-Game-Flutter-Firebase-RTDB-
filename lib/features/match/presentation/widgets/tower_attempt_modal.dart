import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/tower.dart';
import '../controllers/match_controller.dart';

class TowerAttemptModal extends StatefulWidget {
  final Tower tower;
  final int targetValue;
  final MatchController controller;

  const TowerAttemptModal({
    super.key,
    required this.tower,
    required this.targetValue,
    required this.controller,
  });

  @override
  State<TowerAttemptModal> createState() => _TowerAttemptModalState();
}

class _TowerAttemptModalState extends State<TowerAttemptModal> {
  late int currentValue;
  int moves = 0;
  bool isSolving = false;
  bool isUnreachable = false;

  @override
  void initState() {
    super.initState();
    currentValue = widget.tower.startValue;
  }

  void _applyOp(int type) {
    if (isUnreachable) return;

    setState(() {
      if (type == 1) {
        currentValue += 10;
      } else if (type == 2) {
        currentValue *= 2;
      }
      moves++;

      if (currentValue > 200000 || currentValue < 0) {
        isUnreachable = true;
      }
    });

    if (currentValue == widget.targetValue) {
      _finishSolve();
    }
  }

  Future<void> _finishSolve() async {
    setState(() => isSolving = true);

    try {
      bool success = await widget.controller.handleSolveTower(
        widget.tower.id,
        widget.tower.startValue,
        moves,
      ).timeout(const Duration(seconds: 5));

      if (success) {
        Get.back(); // Close modal on success
        Get.snackbar('Success', '+1 Score for your team!', 
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
          snackPosition: SnackPosition.TOP);
      } else {
        if (mounted) setState(() => isSolving = false);
        Get.snackbar('Error', 'Failed to commit solve. Claim might have expired.',
          backgroundColor: Colors.red[100], colorText: Colors.red[800]);
      }
    } catch (e) {
      if (mounted) setState(() => isSolving = false);
      Get.snackbar('Network Error', 'Connection lost or timeout. Try again.',
        backgroundColor: Colors.red[300], colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _restart() {
    setState(() {
      currentValue = widget.tower.startValue;
      moves = 0;
      isUnreachable = false;
    });
  }

  void _cancel() {
    widget.controller.handleCancelClaim(widget.tower.id);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    double ratio = currentValue / widget.targetValue;
    double heightRatio = ratio.clamp(0.2, 0.9);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAD2), // Match Scaffold pale yellow
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Custom Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left side: Back & Restart
                Row(
                  children: [
                    _buildRetroButton(
                      color: const Color(0xFF7986CB), // Indigo Blue
                      label: '<',
                      subLabel: 'Back',
                      onPressed: _cancel,
                      size: 50,
                    ),
                    const SizedBox(width: 12),
                    _buildRetroButton(
                      color: const Color(0xFFDCE775), // Yellow Green
                      label: '↻',
                      subLabel: 'Restart',
                      onPressed: isSolving ? null : _restart,
                      size: 50,
                    ),
                  ],
                ),
                // Right side: Min & Moves
                Row(
                  children: [
                    Obx(() {
                      int mins = widget.controller.remainingSeconds.value ~/ 60;
                      return _buildRetroDisplay(
                        color: const Color(0xFF4DD0E1), // Cyan
                        value: '$mins',
                        label: 'Min',
                      );
                    }),
                    const SizedBox(width: 12),
                    _buildRetroDisplay(
                      color: const Color(0xFFBA68C8), // Purple
                      value: '$moves',
                      label: 'Moves',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Arena (Green Background)
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF81C784), // Light Green
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4CAF50), width: 2),
              ),
              child: Stack(
                children: [
                  // Left Static Target
                  Positioned(
                    left: 24,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.airport_shuttle, color: Colors.white, size: 36),
                        Container(
                          width: 60,
                          height: MediaQuery.of(context).size.height * 0.5,
                          color: const Color(0xFF7E57C2), // Deep Purple
                          alignment: Alignment.topCenter,
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${widget.targetValue}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dynamic Progress Tower
                  Positioned(
                    right: 48,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // The floating value Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isUnreachable ? Colors.red : const Color(0xFFAB47BC), // Lighter Purple
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isUnreachable ? 'OUT OF BOUNDS' : '$currentValue',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                          ),
                        ),
                        // Dynamic bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 120,
                          height: (MediaQuery.of(context).size.height * 0.5 * heightRatio),
                          color: const Color(0xFF7E57C2), // Deep Purple
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action Area
          Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(top: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF673AB7), // Deep Purple Base
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionRetroButton(
                  color: const Color(0xFF8D6E63), // Brown
                  shadowColor: const Color(0xFF5D4037),
                  label: '+10',
                  onPressed: isUnreachable || isSolving ? null : () => _applyOp(1),
                ),
                _buildActionRetroButton(
                  color: const Color(0xFFD4E157), // Golden Yellow
                  shadowColor: const Color(0xFFAFB42B),
                  label: 'X2',
                  onPressed: isUnreachable || isSolving ? null : () => _applyOp(2),
                  textColor: const Color(0xFF827717),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetroButton({required Color color, required String label, required String subLabel, required VoidCallback? onPressed, required double size}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26, // Simple shadow
              offset: Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(subLabel, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildRetroDisplay({required Color color, required String value, required String label}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26, 
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildActionRetroButton({required Color color, required Color shadowColor, required String label, required VoidCallback? onPressed, Color textColor = Colors.white}) {
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        child: Container(
          width: 130,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: shadowColor, 
                offset: const Offset(0, 8), // Hard 3D shadow
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: Text(
              label, 
              style: TextStyle(
                color: textColor, 
                fontWeight: FontWeight.bold, 
                fontSize: 42
              ),
            ),
          ),
        ),
      ),
    );
  }
}
