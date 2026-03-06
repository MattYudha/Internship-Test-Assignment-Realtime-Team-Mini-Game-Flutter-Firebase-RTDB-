import 'package:flutter/foundation.dart';
import 'dart:collection';

class BfsSolver {
  /// Calculates the optimal number of moves from [start] to [target].
  /// Runs on a background isolate using [compute] to prevent main thread blocking.
  static Future<int> getOptimalMoves(int start, int target) async {
    // If we are already at the target, 0 moves needed.
    if (start == target) return 0;
    
    // FAST FAIL HEURISTICS O(1)
    // 1. Strictly sequence check: Ops are +10 and *2. They only increase (or maintain) the value.
    if (start > target) return -1;
    
    // 2. Parity check (Prof's Law): Even + 10 = Even, Even * 2 = Even.
    // If start is Even, it can NEVER reach an Odd target.
    if (start % 2 == 0 && target % 2 != 0) return -1;
    
    // Spawn background isolate
    return await compute(_bfsCalculate, {'start': start, 'target': target});
  }

  /// Synchronous version for use inside other isolates (like the pool generator)
  /// pure Dart function, no external dependencies.
  static int calculateMovesSync(int start, int target) {
    if (start == target) return 0;
    if (start > target) return -1;
    if (start % 2 == 0 && target % 2 != 0) return -1;
    return _bfsCalculate({'start': start, 'target': target});
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
