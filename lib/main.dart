import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';

// Placeholder screen before actual match screen is implemented
class LobbyScreen extends StatelessWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mini Tower Lobby')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // Get.toNamed('/match');
          },
          child: const Text('Start Connecting'),
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init failed (expected with dummy keys): $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Realtime Tower Game',
      theme: AppTheme.lightTheme,
      initialRoute: '/lobby',
      getPages: [
        GetPage(name: '/lobby', page: () => const LobbyScreen()),
      ],
    );
  }
}
