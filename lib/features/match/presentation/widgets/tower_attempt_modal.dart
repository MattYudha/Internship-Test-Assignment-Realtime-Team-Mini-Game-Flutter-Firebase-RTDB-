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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: ${widget.targetValue}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              Text(
                'Moves: $moves',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          Text(
            '$currentValue',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.bold,
              color: isUnreachable ? Colors.red : Colors.black87,
            ),
          ),
          
          if (isUnreachable)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Unreachable (Out of bounds). Please restart.', style: TextStyle(color: Colors.red)),
            ),
            
          const SizedBox(height: 48),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isUnreachable || isSolving ? null : () => _applyOp(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[300],
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: const Text('+ 10', style: TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: isUnreachable || isSolving ? null : () => _applyOp(2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[300],
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: const Text('x 2', style: TextStyle(fontSize: 24)),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _cancel, 
                icon: const Icon(Icons.close, color: Colors.grey), 
                label: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              if (isSolving)
                const CircularProgressIndicator()
              else
                TextButton.icon(
                  onPressed: _restart, 
                  icon: const Icon(Icons.refresh, color: Colors.blue), 
                  label: const Text('Restart', style: TextStyle(color: Colors.blue)),
                ),
            ],
          )
        ],
      ),
    );
  }
}
