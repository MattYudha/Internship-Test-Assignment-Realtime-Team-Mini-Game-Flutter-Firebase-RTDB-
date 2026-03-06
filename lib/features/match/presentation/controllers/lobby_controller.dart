import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../auth/domain/repositories/auth_repository.dart';
import '../domain/usecases/create_match_usecase.dart';
import '../domain/usecases/join_match_usecase.dart';
import '../domain/usecases/generate_tower_pool_usecase.dart';

class LobbyController extends GetxController {
  final AuthRepository authRepo;
  final CreateMatchUseCase createMatchUseCase;
  final JoinMatchUseCase joinMatchUseCase;
  final GenerateTowerPoolUseCase generateTowerPoolUseCase;

  LobbyController({
    required this.authRepo,
    required this.createMatchUseCase,
    required this.joinMatchUseCase,
    required this.generateTowerPoolUseCase,
  });

  final playerNameController = TextEditingController();
  final isConnecting = false.obs;
  final loadingMessage = ''.obs;

  @override
  void onClose() {
    playerNameController.dispose();
    super.onClose();
  }

  Future<void> findOrHostMatch() async {
    final name = playerNameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Error', 'Please enter your name', backgroundColor: Colors.red[100], colorText: Colors.red[800]);
      return;
    }

    isConnecting.value = true;
    
    try {
      loadingMessage.value = 'Signing in asynchronously...';
      final user = await authRepo.signInAnonymously();
      
      if (user == null) {
        throw Exception('Authentication failed');
      }

      loadingMessage.value = 'Looking for an active match...';
      // ATTEMPT 1: Join an existing waiting match
      String? joinResult = await joinMatchUseCase(user.id, name);

      if (joinResult == null) {
        // Queue was empty. We must become the Host.
        loadingMessage.value = 'No match found. Generating new arena (this may take a moment)...';
        
        // heavy lifting on background isolate
        final towerPool = await generateTowerPoolUseCase(); 
        
        loadingMessage.value = 'Uploading arena to server...';
        // Try to create and win the queue
        String? newMatchId = await createMatchUseCase(towerPool, 1000);

        if (newMatchId == null) {
          // We LOST the optimistic concurrency race. Someone else built a match in that exact microsecond window.
          // Retry joining immediately.
          loadingMessage.value = 'Arena collision detected. Redirecting to winning match...';
          joinResult = await joinMatchUseCase(user.id, name);
          
          if (joinResult == null) {
              throw Exception('Critical matchmaking collision. Please try again.');
          }
        } else {
          // We WON the optimistic creation. 
          // We must now insert ourselves as the first player (Host -> Team A usually)
          loadingMessage.value = 'Arena secured. Joining...';
          joinResult = await joinMatchUseCase(user.id, name);
          if (joinResult == null) throw Exception('Failed to join our own generated match.');
        }
      }

      // At this point joinResult is definitely in format: "matchId|teamA"
      final parts = joinResult.split('|');
      final matchId = parts[0];
      final teamId = parts[1];

      // Route to match providing the critical dependencies!
      Get.offAllNamed('/match', arguments: {
        'matchId': matchId,
        'teamId': teamId,
        'playerId': user.id,
      });

    } catch (e) {
      Get.snackbar('Connection Error', e.toString(), 
          backgroundColor: Colors.red[300], colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isConnecting.value = false;
    }
  }
}
