import 'package:get/get.dart';
import 'package:flutter/material.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/usecases/create_match_usecase.dart';
import '../../domain/usecases/join_match_usecase.dart';
import '../../domain/usecases/generate_tower_pool_usecase.dart';
import '../../domain/entities/join_match_result.dart';

class LobbyController extends GetxController {
  final AuthRepository authRepo;
  final MatchRepository matchRepo;
  final CreateMatchUseCase createMatchUseCase;
  final JoinMatchUseCase joinMatchUseCase;
  final GenerateTowerPoolUseCase generateTowerPoolUseCase;

  LobbyController({
    required this.authRepo,
    required this.matchRepo,
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
      JoinMatchResult joinResult = await joinMatchUseCase(user, name);

      if (joinResult.status == JoinMatchStatus.error) {
        // Queue was empty or match ended. We must become the Host.
        loadingMessage.value = 'No match found. Generating new arena (this may take a moment)...';
        
        // heavy lifting on background isolate
        final towerPool = await generateTowerPoolUseCase(); 
        
        loadingMessage.value = 'Uploading arena to server...';
        print('Tower pool generated with length: ${towerPool.length}');
        
        // Try to create and win the queue
        String? newMatchId = await createMatchUseCase(towerPool, 1000, user);

        if (newMatchId == null) {
          // We LOST the optimistic concurrency race. Someone else built a match in that exact microsecond window.
          // Retry joining immediately.
          loadingMessage.value = 'Arena collision detected. Redirecting to winning match...';
          joinResult = await joinMatchUseCase(user, name);
          
          if (joinResult.status == JoinMatchStatus.error) {
              throw Exception('Critical matchmaking collision. Please try again.');
          }
        } else {
          print('We WON the optimistic creation. Match ID: $newMatchId');
          // We WON the optimistic creation. 
          // We must now insert ourselves as the first player (Host -> Team A usually)
          loadingMessage.value = 'Arena secured. Joining...';
          joinResult = await joinMatchUseCase(user, name);
          if (joinResult.status == JoinMatchStatus.error) {
            print('Failed to join our own generated match.');
            throw Exception('Failed to join our own generated match.');
          }
        }
      }

      // Explicitly reject Late Joins per Prof's Review Rule #1
      if (joinResult.status == JoinMatchStatus.lateJoinRejected) {
        Get.snackbar('Match Running', 'A match is already running. You cannot late join. Please wait for the next match.', 
            backgroundColor: Colors.orange[200], colorText: Colors.black87, duration: const Duration(seconds: 4));
        return;
      } else if (joinResult.status == JoinMatchStatus.matchFull) {
        Get.snackbar('Room Full', 'The current match is full (Max 8 players).', 
            backgroundColor: Colors.orange[200], colorText: Colors.black87, duration: const Duration(seconds: 4));
        return;
      }

      if (joinResult.matchId == null || joinResult.teamId == null) {
        throw Exception('System error: missing match routing data.');
      }

      // Route to match providing the critical dependencies!
      Get.offAllNamed('/match', arguments: {
        'matchId': joinResult.matchId,
        'teamId': joinResult.teamId,
        'playerId': user,
      });

    } catch (e) {
      Get.snackbar('Connection Error', e.toString(), 
          backgroundColor: Colors.red[300], colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } finally {
      isConnecting.value = false;
    }
  }

  Future<void> debugResetSession() async {
    isConnecting.value = true;
    loadingMessage.value = 'Cleaning up ghost player...';
    try {
      final String uid = authRepo.getCurrentUid() ?? '';
      if (uid.isNotEmpty) {
        // Clean up from active waiting lobby if they are in one
        await matchRepo.debugCleanupGhostPlayer(uid);
      }
      loadingMessage.value = 'Signing out anonymous session...';
      await authRepo.signOut();
      
      Get.snackbar('Session Reset', 'You will be issued a fresh anonymous UID on next play.', 
          backgroundColor: Colors.green[200], colorText: Colors.black87);
    } catch (e) {
      Get.snackbar('Cleanup Error', e.toString(), 
          backgroundColor: Colors.red[300], colorText: Colors.white);
    } finally {
      isConnecting.value = false;
    }
  }
}
