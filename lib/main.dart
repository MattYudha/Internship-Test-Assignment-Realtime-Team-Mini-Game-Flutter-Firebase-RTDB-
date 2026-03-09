import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
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
  } catch (e) {
    debugPrint("Firebase init failed (expected with dummy keys): $e");
  }

  runApp(const RealtimeMiniGameApp());
}

class RealtimeMiniGameApp extends StatelessWidget {
  const RealtimeMiniGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Realtime Tower Mini-Game',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialBinding: InitBinding(), // Initialize Core Injectables
      initialRoute: '/lobby',
      getPages: [
        GetPage(
          name: '/lobby',
          binding: LobbyBinding(),
          page: () => const LobbyScreen(),
        ),
        GetPage(
          name: '/match',
          binding: BindingsBuilder(() {
            final args = Get.arguments as Map<String, dynamic>? ?? {};
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
