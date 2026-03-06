import 'package:flutter_test/flutter_test.dart';
import 'package:mini_tower_game/features/match/domain/usecases/bfs_solver.dart';

void main() {
  group('BfsSolver', () {
    test('returns 0 when start == target', () {
      expect(BfsSolver.calculateMovesSync(50, 50), 0);
    });

    test('returns optimal path for basic scenario', () {
      // 10 -> 20 (+10 or *2, path is 1)
      expect(BfsSolver.calculateMovesSync(10, 20), 1);
      
      // 10 -> 40 (10 * 2 = 20, 20 * 2 = 40, path is 2)
      expect(BfsSolver.calculateMovesSync(10, 40), 2);
      
      // 5 -> 30 (5 + 10 = 15, 15 * 2 = 30, path is 2)
      expect(BfsSolver.calculateMovesSync(5, 30), 2);
    });

    test('FAST FAIL: returns -1 for mathematically unreachable states (Even Start -> Odd Target)', () {
      // Target is odd, start is even
      expect(BfsSolver.calculateMovesSync(10, 15), -1);
      expect(BfsSolver.calculateMovesSync(20, 25), -1);
      expect(BfsSolver.calculateMovesSync(2, 99), -1);
    });

    test('FAST FAIL: returns -1 if start > target', () {
      expect(BfsSolver.calculateMovesSync(100, 50), -1);
      expect(BfsSolver.calculateMovesSync(200000, 10), -1);
    });

    test('getOptimalMoves async works correctly', () async {
      final moves = await BfsSolver.getOptimalMoves(10, 40);
      expect(moves, 2);
      
      final failMoves = await BfsSolver.getOptimalMoves(10, 17);
      expect(failMoves, -1);
    });
  });
}
