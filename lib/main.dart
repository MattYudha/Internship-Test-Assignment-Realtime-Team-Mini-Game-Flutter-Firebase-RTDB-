import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/di/init_binding.dart';
import 'features/match/presentation/pages/lobby_screen.dart';
import 'features/match/presentation/pages/match_page.dart';
import 'features/match/data/repositories/match_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/match/domain/usecases/claim_tower_usecase.dart';
import 'features/match/domain/usecases/solve_tower_usecase.dart';
import 'features/match/presentation/controllers/lobby_controller.dart';
import 'features/match/presentation/controllers/match_controller.dart';
import 'core/di/lobby_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await Get.putAsync<SharedPreferences>(() async => await SharedPreferences.getInstance());
  } catch (e) {
    debugPrint("Firebase init failed (expected with dummy keys): $e");
  }

  // ── Session Persistence: check if player has an active session ──
  String? sessionRoute;
  Map<String, dynamic>? sessionArgs;

  try {
    final prefs = Get.find<SharedPreferences>();
    final savedUid     = prefs.getString('session_uid');
    final savedMatchId = prefs.getString('session_match_id');
    final savedTeamId  = prefs.getString('session_team_id');

    if (savedUid != null && savedMatchId != null && savedTeamId != null) {
      // Verify the match is still running before auto-routing
      final statusSnap = await FirebaseDatabase.instance
          .ref('matches/$savedMatchId/meta/status')
          .get();

      if (statusSnap.exists && statusSnap.value == 'running') {
        sessionRoute = '/match';
        sessionArgs = {
          'matchId': savedMatchId,
          'teamId': savedTeamId,
          'playerId': savedUid,
        };
        debugPrint('[Session] Rejoining match $savedMatchId as $savedTeamId');
      } else {
        // Match ended or not found — clear stale session
        await prefs.remove('session_uid');
        await prefs.remove('session_match_id');
        await prefs.remove('session_team_id');
        await prefs.remove('session_display_name');
        debugPrint('[Session] Saved match not running. Cleared session.');
      }
    }
  } catch (e) {
    debugPrint('[Session] Check failed: $e');
  }

  runApp(RealtimeMiniGameApp(
    initialRoute: sessionRoute ?? '/lobby',
    initialArgs: sessionArgs,
  ));
}

class RealtimeMiniGameApp extends StatelessWidget {
  final String initialRoute;
  final Map<String, dynamic>? initialArgs;

  const RealtimeMiniGameApp({
    super.key,
    this.initialRoute = '/lobby',
    this.initialArgs,
  });

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Realtime Tower Mini-Game By Matt',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialBinding: InitBinding(),
      initialRoute: initialRoute,
      getPages: [
        GetPage(
          name: '/lobby',
          binding: LobbyBinding(),
          page: () => const LobbyScreen(),
        ),
        GetPage(
          name: '/match',
          // When auto-routing from session (initialRoute = /match),
          // GetX will use these arguments in the binding instead of navigation args.
          arguments: initialArgs,
          binding: BindingsBuilder(() {
            final args = (Get.arguments as Map<String, dynamic>?) ?? {};
            Get.lazyPut(() => MatchController(
              Get.find<MatchRepositoryImpl>(),
              Get.find<AuthRepository>(),
              Get.find<ClaimTowerUseCase>(),
              Get.find<SolveTowerUseCase>(),
              args['matchId'] ?? '',
              args['teamId'] ?? '',
            ));
          }),
          page: () => const MatchPage(),
        ),
      ],
    );
  }
}
