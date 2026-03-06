import 'dart:math';
import 'package:flutter/foundation.dart';
import 'bfs_solver.dart';

class GenerateTowerPoolUseCase {
  /// Asynchronously generates an array of 500 solvable target values for the `towerPool`.
  /// Uses a single-batch isolate to prevent main thread blocking and avoid isolate spawn overhead.
  Future<List<int>> call({int size = 500, int min = 5, int max = 100, int targetValue = 1000}) async {
    return await compute(_generateValidPoolInBackground, {
      'size': size,
      'min': min,
      'max': max,
      'targetValue': targetValue,
    });
  }
}

/// Top-level pure Dart function for the single-batch isolate.
/// MUST NOT contain any Flutter dependencies or Get.find() calls.
List<int> _generateValidPoolInBackground(Map<String, int> args) {
  final int size = args['size']!;
  final int min = args['min']!;
  final int max = args['max']!;
  final int targetValue = args['targetValue']!;
  
  final random = Random();
  List<int> pool = [];
  
  while (pool.length < size) {
    int startValue = min + random.nextInt(max - min + 1);
    
    // Synchronously check solvability using a pure function
    int moves = BfsSolver.calculateMovesSync(startValue, targetValue);
    
    // If reachable (-1 means unreachable), add to pool
    if (moves != -1) {
      pool.add(startValue);
    }
  }
  
  return pool;
}
