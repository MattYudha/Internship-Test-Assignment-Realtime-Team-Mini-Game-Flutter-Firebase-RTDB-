import 'dart:math';

class GenerateTowerPoolUseCase {
  /// Generates an array of solvable target values for the `towerPool`.
  /// We generate [size] numeric values ranging [min] to [max].
  List<int> call({int size = 500, int min = 5, int max = 100}) {
    final random = Random();
    List<int> pool = [];
    
    for (int i = 0; i < size; i++) {
      // Must be solvable. Since the target is a specific number (e.g. 1000), 
      // For now, ANY number in 5..100 is valid as a starting point.
      // But we can just create randoms. Unreachability is possible but that's part of the game rules.
      pool.add(min + random.nextInt(max - min + 1));
    }
    
    return pool;
  }
}
