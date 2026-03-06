import 'package:flutter/foundation.dart';
import 'dart:collection';

class BfsSolver {
  /// Calculates the optimal number of moves from [start] to [target].
  /// Runs on a background isolate using [compute] to prevent main thread blocking.
  static Future<int> getOptimalMoves(int start, int target) async {
    // If we are already at the target, 0 moves needed.
    if (start == target) return 0;
    
    // Spawn background isolate
    return await compute(_bfsCalculate, {'start': start, 'target': target});
  }

  /// The heavy lifting function to be run in pure Dart isolate.
  static int _bfsCalculate(Map<String, int> args) {
    int start = args['start']!;
    int target = args['target']!;
    
    if (start == target) return 0;

    Queue<MapEntry<int, int>> queue = Queue();
    Set<int> visited = {};

    queue.add(MapEntry(start, 0));
    visited.add(start);

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final currentVal = current.key;
      final moves = current.value;

      // Operations: f(x) = x + 10, g(x) = x * 2
      final next1 = currentVal + 10;
      final next2 = currentVal * 2;

      for (int nextVal in [next1, next2]) {
        if (nextVal == target) {
          return moves + 1;
        }

        // Check bounds (0 <= x <= 200000)
        if (nextVal <= 200000 && !visited.contains(nextVal)) {
          visited.add(nextVal);
          queue.add(MapEntry(nextVal, moves + 1));
        }
      }
    }

    // Unreachable
    return -1;
  }
}
