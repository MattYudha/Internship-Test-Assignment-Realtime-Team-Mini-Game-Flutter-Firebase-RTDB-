import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/lobby_controller.dart';

class LobbyScreen extends GetView<LobbyController> {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.account_tree_rounded,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 24),
              Text(
                'Realtime Tower\nMini-Game',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 48),
              
              const Text(
                'Enter your display name to join:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              TextField(
                controller: controller.playerNameController,
                decoration: InputDecoration(
                  hintText: 'e.g. Player 1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              
              const SizedBox(height: 32),

              Obx(() => controller.isConnecting.value
                  ? Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          controller.loadingMessage.value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: () => controller.findOrHostMatch(),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('FIND MATCH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => controller.debugResetSession(),
                            icon: const Icon(Icons.refresh, color: Colors.orange),
                            label: const Text(
                              'Debug: Reset Auth Session\n(Creates new anonymous UID/Cleans Ghost slots)',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ]
                      ],
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
