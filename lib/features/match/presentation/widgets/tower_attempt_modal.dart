import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/tower.dart';
import '../../domain/usecases/bfs_solver.dart';
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

class _TowerAttemptModalState extends State<TowerAttemptModal> with SingleTickerProviderStateMixin {
  late int currentValue;
  int moves = 0;
  bool isSolving = false;
  
  // Unreachable state: true if BFS proves currentValue cannot reach target
  bool isUnreachable = false;
  
  // Optimal moves for display (loaded async at start)
  int? optimalMoves;
  bool _loadingOptimal = true;

  late AnimationController _successAnimController;
  late Animation<double> _scaleAnimation;
  
  // Auto-renew timer: silently refreshes the claim every 30s so the player
  // never loses ownership while the modal is open.
  Timer? _claimRenewTimer;

  @override
  void initState() {
    super.initState();
    currentValue = widget.tower.startValue;

    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _successAnimController, curve: Curves.elasticOut),
    );
    
    // Load optimal moves using BFS (async, non-blocking)
    _loadOptimalMoves();
    
    // Renew claim every 30 seconds while modal is open to prevent expiry mid-solve
    _claimRenewTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isSolving && mounted) {
        widget.controller.handleClaimTower(widget.tower.id);
      }
    });
  }

  Future<void> _loadOptimalMoves() async {
    final result = await BfsSolver.getOptimalMoves(widget.tower.startValue, widget.targetValue);
    if (mounted) {
      setState(() {
        optimalMoves = result >= 0 ? result : null;
        _loadingOptimal = false;
        // Also check if the starting value itself is unreachable (should never happen with valid pool)
        if (result < 0) isUnreachable = true;
      });
    }
  }

  @override
  void dispose() {
    _claimRenewTimer?.cancel();
    _successAnimController.dispose();
    super.dispose();
  }

  /// Per rules: each button is disabled independently based on whether THAT operation exceeds bounds.
  /// User request: ALSO disable buttons entirely if currentValue > targetValue (Overshoot not allowed).
  bool get canAdd10 => !isSolving && !isUnreachable && currentValue <= widget.targetValue && (currentValue + 10) <= 200000;
  bool get canMul2  => !isSolving && !isUnreachable && currentValue <= widget.targetValue && (currentValue * 2) <= 200000;

  void _applyOp(int type) {
    setState(() {
      if (type == 1) {
        currentValue += 10;
      } else if (type == 2) {
        currentValue *= 2;
      }
      moves++;
    });

    // After applying, check if we've solved or gone out of bounds
    if (currentValue == widget.targetValue) {
      _finishSolve();
      return;
    }

    // If both operations would now exceed 200,000 (or we're past target), mark unreachable
    final nextAdd = currentValue + 10;
    final nextMul = currentValue * 2;
    if ((nextAdd > 200000 && nextMul > 200000) || currentValue > widget.targetValue) {
      setState(() => isUnreachable = true);
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
        if (mounted) {
          _successAnimController.forward();
          await Future.delayed(const Duration(milliseconds: 700));
        }
        Get.back();
        Get.snackbar('🏆 Tower Solved!', '+1 Score for your team!', 
          backgroundColor: Colors.green[100],
          colorText: Colors.green[800],
          snackPosition: SnackPosition.TOP);
      } else {
        if (mounted) setState(() => isSolving = false);
        Get.snackbar(
          'Solution Rejected', 
          'Time or moves exceeded possible limit. Please try again.',
          backgroundColor: const Color(0xFFD32F2F), 
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
          borderRadius: 12,
        );
      }
    } catch (e) {
      if (mounted) setState(() => isSolving = false);
      Get.snackbar(
        'Network Error', 
        'Connection lost or timeout. Try again.',
        backgroundColor: Colors.red[300], 
        colorText: Colors.white, 
        snackPosition: SnackPosition.BOTTOM,
      );
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
    double ratio = (currentValue / widget.targetValue).clamp(0.0, 1.0);
    double heightRatio = ratio.clamp(0.1, 0.95);

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAD2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ─── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Back & Restart
                Row(
                  children: [
                    _buildRetroButton(
                      color: const Color(0xFF7986CB),
                      label: '<',
                      subLabel: 'Back',
                      onPressed: _cancel,
                      size: 50,
                    ),
                    const SizedBox(width: 10),
                    _buildRetroButton(
                      color: const Color(0xFFDCE775),
                      label: '↻',
                      subLabel: 'Restart',
                      onPressed: isSolving ? null : _restart,
                      size: 50,
                    ),
                  ],
                ),
                // Right: Timer + Moves
                Row(
                  children: [
                    Obx(() {
                      int mins = widget.controller.remainingSeconds.value ~/ 60;
                      return _buildRetroDisplay(
                        color: const Color(0xFF4DD0E1),
                        value: '$mins',
                        label: 'Min',
                      );
                    }),
                    const SizedBox(width: 10),
                    _buildRetroDisplay(
                      color: const Color(0xFFBA68C8),
                      value: '$moves',
                      label: 'Moves',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Optimal Moves Banner ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF673AB7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Start: ${widget.tower.startValue}  →  Target: ${widget.targetValue}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  _loadingOptimal
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        optimalMoves != null
                          ? 'Best possible: $optimalMoves moves'
                          : '⚠️ Unreachable from start',
                        style: TextStyle(
                          color: optimalMoves != null ? const Color(0xFFFFD54F) : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                ],
              ),
            ),
          ),

          // ─── Main Arena ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: const Color(0xFF81C784),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF4CAF50), width: 2),
              ),
              child: Stack(
                children: [
                  // Left: Static Target Tower
                  Positioned(
                    left: 24,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.airport_shuttle, color: Colors.white, size: 32),
                        Container(
                          width: 60,
                          height: MediaQuery.of(context).size.height * 0.48,
                          color: const Color(0xFF7E57C2),
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

                  // Right: Dynamic Progress Tower
                  Positioned(
                    right: 40,
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Current value pill with animation
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isUnreachable
                                ? const Color(0xFFF57F17)  // Calm amber on limit
                                : (currentValue >= widget.targetValue
                                  ? Colors.green.shade700
                                  : const Color(0xFFAB47BC)),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(60),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Text(
                              isUnreachable ? '⚠️  $currentValue' : '$currentValue',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                        // Animated bar
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          width: 110,
                          height: MediaQuery.of(context).size.height * 0.48 * heightRatio,
                          decoration: BoxDecoration(
                            color: isUnreachable
                              ? const Color(0xFFF57F17)  // Amber instead of red
                              : const Color(0xFF7E57C2),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Calm limit-reached banner (replaces aggressive full-screen red overlay)
                  if (isUnreachable)
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF57F17).withOpacity(0.92),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Limit reached — tap Restart to continue',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ─── Action Buttons ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            margin: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF673AB7),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // +10 button — disabled independently if +10 > 200,000
                _buildActionButton(
                  color: const Color(0xFF8D6E63),
                  shadowColor: const Color(0xFF5D4037),
                  label: '+10',
                  enabled: canAdd10,
                  onPressed: () => _applyOp(1),
                ),
                // X2 button — disabled independently if x2 > 200,000
                _buildActionButton(
                  color: const Color(0xFFD4E157),
                  shadowColor: const Color(0xFFAFB42B),
                  label: 'X2',
                  textColor: const Color(0xFF827717),
                  enabled: canMul2,
                  onPressed: () => _applyOp(2),
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
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 0)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(subLabel, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            ],
          ),
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
        boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 4), blurRadius: 0)],
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

  Widget _buildActionButton({
    required Color color,
    required Color shadowColor,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
    Color textColor = Colors.white,
  }) {
    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: 130,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
              ? [BoxShadow(color: shadowColor, offset: const Offset(0, 8), blurRadius: 0)]
              : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 42),
            ),
          ),
        ),
      ),
    );
  }
}
