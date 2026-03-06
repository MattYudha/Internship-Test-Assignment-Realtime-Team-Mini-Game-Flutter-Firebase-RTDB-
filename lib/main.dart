import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/di/init_binding.dart';
import 'features/match/presentation/pages/lobby_screen.dart';
import 'features/match/presentation/pages/match_page.dart';

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
          page: () => LobbyScreen(),
        ),
        GetPage(
          name: '/match',
          // MatchPage receives injected arguments
          page: () => MatchPage(
            matchId: Get.arguments['matchId'],
            teamId: Get.arguments['teamId'],
            playerId: Get.arguments['playerId'],
          ),
        ),
      ],
    );
  }
}
