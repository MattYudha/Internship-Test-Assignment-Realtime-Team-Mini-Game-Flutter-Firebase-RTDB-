import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mini_tower_game/features/match/data/repositories/match_repository_impl.dart';

/// IMPORTANT: To run this test successfully, you must:
/// 1. Start the Firebase Local Emulator Suite (`firebase emulators:start`)
/// 2. Run this test in an integration context (e.g., `flutter test integration_test/` 
///    or on a real device/simulator) because `firebase_database` requires native channels.
void main() {
  late MatchRepositoryImpl repo;
  late FirebaseDatabase db;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Assuming Firebase is initialized by the test runner (e.g. via integration_test)
    // await Firebase.initializeApp();
  });

  setUp(() {
    // 1. Point instance to the RTDB Local Emulator (as requested by Professor)
    db = FirebaseDatabase.instance;
    db.useDatabaseEmulator('127.0.0.1', 9000);
    
    // Inject the emulator DB into our repository
    repo = MatchRepositoryImpl(db: db);
  });

  test('Claim Tower Concurrency (Future.wait) - Only one transaction should succeed', () async {
    final matchId = 'test_match_concurrency';
    final teamId = 'teamA';
    final towerId = 'tower_99';
    
    // 2. Seed the initial available state into the local emulator
    await db.ref('matches/$matchId/teams/$teamId/towers/$towerId').set({
      'startValue': 100,
      'state': 'available',
      'claimedBy': null,
    });

    // 3. Execute Concurrency Attack! 
    // Two users trying to claim the exact same tower at the exact same millisecond.
    final results = await Future.wait([
      repo.claimTower(matchId, teamId, towerId, 'hacker_player_1'),
      repo.claimTower(matchId, teamId, towerId, 'hacker_player_2'),
    ]);

    // 4. Verification: The RTDB runTransaction MUST lock and abort one of them.
    int successCount = results.where((r) => r == true).length;
    int failCount = results.where((r) => r == false).length;

    expect(successCount, 1, reason: 'Race condition failed: Both players claimed it!');
    expect(failCount, 1, reason: 'One transaction must abort safely.');

    // 5. Verify Final State in DB
    final snapshot = await db.ref('matches/$matchId/teams/$teamId/towers/$towerId').get();
    final data = snapshot.value as Map<dynamic, dynamic>;
    
    expect(data['state'], 'claimed');
    expect(data['claimedBy'], isNotNull);
    
    // It should be either hacker 1 or hacker 2, never null or overwritten weirdly.
    expect(
      data['claimedBy'] == 'hacker_player_1' || data['claimedBy'] == 'hacker_player_2', 
      true
    );
  });
}
