import 'dart:math';
import 'package:flutter/foundation.dart';
import 'bfs_solver.dart';

class GenerateTowerPoolUseCase {
  /// Asynchronously generates an array of 500 solvable target values for the `towerPool`.
  /// Uses a single-batch isolate to prevent main thread blocking and avoid isolate spawn overhead.
  Future<List<int>> call({int size = 500, int min = 50, int max = 250, int targetValue = 1000}) async {
    return await compute(_generateValidPoolInBackground, {
      'size': size,
      'min': min,
      'max': max,
      'targetValue': targetValue,
    });
  }
}

List<int> _generateValidPoolInBackground(Map<String, int> args) {
  final int size = args['size']!;
  final int minLimit = args['min']!;
  final int maxLimit = args['max']!;
  final int targetValue = args['targetValue']!;
  
  // We need to find `size` numbers between `minLimit` and `maxLimit`
  // that can reach `targetValue` using only +10 and *2.
  // We can do this extremely fast by working BACKWARDS from the target.
  // Inverse operations: f'(x) = x - 10, g'(x) = x / 2 (only if x is even)
  
  Set<int> validStarts = {};
  List<int> queue = [targetValue];
  int head = 0;
  
  while (head < queue.length) {
    int current = queue[head++];
    
    // Check if current is within our desired spawn range and is a multiple of 5
    if (current >= minLimit && current <= maxLimit && current % 5 == 0) {
      validStarts.add(current);
      if (validStarts.length >= size * 2) {
        break; // We have enough candidates
      }
    }
    
    // Operation 1: Reverse of +10 is -10
    int prev1 = current - 10;
    if (prev1 >= minLimit && prev1 > 0 && !validStarts.contains(prev1)) {
      queue.add(prev1);
    }
    
    // Operation 2: Reverse of *2 is /2 (only valid if even)
    if (current % 2 == 0) {
      int prev2 = current ~/ 2;
      if (prev2 >= minLimit && prev2 > 0 && !validStarts.contains(prev2)) {
        queue.add(prev2);
      }
    }
  }
  
  final random = Random();
  List<int> candidates = validStarts.toList();
  List<int> pool = [];
  
  if (candidates.isEmpty) {
    // Fallback if mathematically impossible (shouldn't happen with 1000)
    for (int i=0; i<size; i++) pool.add(10);
    return pool;
  }
  
  // Pick random numbers from our valid candidates
  while (pool.length < size) {
    pool.add(candidates[random.nextInt(candidates.length)]);
  }
  
  return pool;
}
