import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/usecases/create_match_usecase.dart';
import '../../domain/usecases/join_match_usecase.dart';
import '../../domain/usecases/generate_tower_pool_usecase.dart';
import '../../domain/entities/join_match_result.dart';

/// Type-safe team enum
enum LobbyTeam { a, b }

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

  // Team selection state
  final Rx<LobbyTeam?> selectedTeam = Rx<LobbyTeam?>(null);

  // Live team counts from Firebase (streamed)
  final RxInt countA = 0.obs;
  final RxInt countB = 0.obs;

  StreamSubscription? _teamCountsSubscription;

  @override
  void onInit() {
    super.onInit();
    _startTeamCountsStream();
  }

  /// Start streaming meta/teamCounts from the active waiting match
  void _startTeamCountsStream() {
    final sysRef = FirebaseDatabase.instance.ref('system/waiting_match');
    sysRef.onValue.listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return;
      final matchId = event.snapshot.value as String;
      _teamCountsSubscription?.cancel();
      _teamCountsSubscription = FirebaseDatabase.instance
          .ref('matches/$matchId/meta/teamCounts')
          .onValue
          .listen((e) async {
            if (!e.snapshot.exists) return;
            final data = Map<dynamic, dynamic>.from(e.snapshot.value as Map);
            int rawA = (data['teamA'] as num?)?.toInt() ?? 0;
            int rawB = (data['teamB'] as num?)?.toInt() ?? 0;

            // Auto-reconcile: if any count exceeds 4, scan real players and fix Firebase
            if (rawA > 4 || rawB > 4) {
              final playersSnap = await FirebaseDatabase.instance
                  .ref('matches/$matchId/players')
                  .get();
              int trueA = 0;
              int trueB = 0;
              if (playersSnap.exists && playersSnap.value != null) {
                final players = Map<dynamic, dynamic>.from(playersSnap.value as Map);
                for (final entry in players.entries) {
                  // Skip bots — they are transient
                  final uid = entry.key as String;
                  if (uid.startsWith('bot_')) continue;
                  final team = (entry.value as Map)['team'] as String?;
                  if (team == 'teamA') trueA++;
                  else if (team == 'teamB') trueB++;
                }
              }
              // Clamp to max 4 per team
              trueA = trueA.clamp(0, 4);
              trueB = trueB.clamp(0, 4);
              // Write the corrected counts back to Firebase
              await FirebaseDatabase.instance
                  .ref('matches/$matchId/meta/teamCounts')
                  .set({'teamA': trueA, 'teamB': trueB});
              countA.value = trueA;
              countB.value = trueB;
            } else {
              countA.value = rawA;
              countB.value = rawB;
            }
          });
    });
  }

  @override
  void onClose() {
    _teamCountsSubscription?.cancel();
    playerNameController.dispose();
    super.onClose();
  }

  /// Join with optional preferred team. null = Quick Join (auto-balance)
  Future<void> findOrHostMatch({LobbyTeam? preferredTeam}) async {
    final name = playerNameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Name Required', 'Please enter your display name before joining.',
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(12),
          borderRadius: 12);
      return;
    }

    // Local Fast-Fail Capacity Pre-check
    if (preferredTeam == LobbyTeam.a && countA.value >= 4) {
      Get.snackbar('Team A is Full', 'Please choose Team B.',
          backgroundColor: Colors.orange[700], colorText: Colors.white, snackPosition: SnackPosition.TOP);
      return;
    }
    if (preferredTeam == LobbyTeam.b && countB.value >= 4) {
      Get.snackbar('Team B is Full', 'Please choose Team A.',
          backgroundColor: Colors.orange[700], colorText: Colors.white, snackPosition: SnackPosition.TOP);
      return;
    }
    if (preferredTeam == null && (countA.value + countB.value) >= 8) {
      Get.snackbar('Match Full', 'The current match is full (Max 8 players).',
          backgroundColor: Colors.orange[700], colorText: Colors.white, snackPosition: SnackPosition.TOP);
      return;
    }

    isConnecting.value = true;

    try {
      loadingMessage.value = 'Signing in...';
      final user = await authRepo.signInAnonymously();
      if (user == null) throw Exception('Authentication failed');

      final preferredTeamStr = preferredTeam == null
          ? null
          : (preferredTeam == LobbyTeam.a ? 'teamA' : 'teamB');

      loadingMessage.value = 'Looking for an active match...';
      JoinMatchResult joinResult = await joinMatchUseCase(user, name, preferredTeam: preferredTeamStr);

      if (joinResult.status == JoinMatchStatus.error) {
        loadingMessage.value = 'No match found. Generating new arena...';
        final towerPool = await generateTowerPoolUseCase();

        loadingMessage.value = 'Uploading arena to server...';
        if (kDebugMode) print('Tower pool generated with length: ${towerPool.length}');

        String? newMatchId = await createMatchUseCase(towerPool, 1000, user);

        if (newMatchId == null) {
          loadingMessage.value = 'Arena collision detected. Redirecting...';
          joinResult = await joinMatchUseCase(user, name, preferredTeam: preferredTeamStr);
          if (joinResult.status == JoinMatchStatus.error) {
            throw Exception('Critical matchmaking collision. Please try again.');
          }
        } else {
          loadingMessage.value = 'Arena secured. Joining...';
          joinResult = await joinMatchUseCase(user, name, preferredTeam: preferredTeamStr);
          if (joinResult.status == JoinMatchStatus.error) {
            throw Exception('Failed to join our own generated match.');
          }
        }
      }

      // Handle team full
      if (joinResult.status == JoinMatchStatus.teamFull) {
        final teamName = preferredTeam == LobbyTeam.a ? 'Team A' : 'Team B';
        Get.snackbar('$teamName is Full',
            joinResult.message ?? 'Please choose the other team.',
            backgroundColor: Colors.orange[700],
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
            margin: const EdgeInsets.all(12),
            borderRadius: 12);
        return;
      }

      // Reject late join
      if (joinResult.status == JoinMatchStatus.lateJoinRejected) {
        Get.snackbar('Match In Progress',
            'A match is already running. Please wait for the next match.',
            backgroundColor: Colors.orange[200], colorText: Colors.black87,
            duration: const Duration(seconds: 4));
        return;
      } else if (joinResult.status == JoinMatchStatus.matchFull) {
        Get.snackbar('Room Full', 'The current match is full (Max 8 players).',
            backgroundColor: Colors.orange[200], colorText: Colors.black87,
            duration: const Duration(seconds: 4));
        return;
      }

      if (joinResult.matchId == null || joinResult.teamId == null) {
        throw Exception('System error: missing match routing data.');
      }

      // ── Save session for rejoin on app reopen ──
      await _saveSession(
        uid: user,
        matchId: joinResult.matchId!,
        teamId: joinResult.teamId!,
        displayName: name,
      );

      Get.offAllNamed('/match', arguments: {
        'matchId': joinResult.matchId,
        'teamId': joinResult.teamId,
        'playerId': user,
      });
    } catch (e) {
      Get.snackbar('Connection Error', e.toString(),
          backgroundColor: Colors.red[300], colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isConnecting.value = false;
    }
  }

  static Future<void> _saveSession({
    required String uid,
    required String matchId,
    required String teamId,
    required String displayName,
  }) async {
    try {
      final prefs = Get.find<SharedPreferences>();
      await prefs.setString('session_uid', uid);
      await prefs.setString('session_match_id', matchId);
      await prefs.setString('session_team_id', teamId);
      await prefs.setString('session_display_name', displayName);
    } catch (_) {}
  }

  static Future<void> clearSession() async {
    try {
      final prefs = Get.find<SharedPreferences>();
      await prefs.remove('session_uid');
      await prefs.remove('session_match_id');
      await prefs.remove('session_team_id');
      await prefs.remove('session_display_name');
    } catch (_) {}
  }

  Future<void> debugResetSession() async {
    isConnecting.value = true;
    loadingMessage.value = 'Cleaning up ghost player...';
    try {
      final String uid = authRepo.getCurrentUid() ?? '';
      if (uid.isNotEmpty) {
        await matchRepo.debugCleanupGhostPlayer(uid);
      }
      await clearSession();
      loadingMessage.value = 'Signing out anonymous session...';
      await authRepo.signOut();
      Get.snackbar('Session Reset',
          'You will be issued a fresh anonymous UID on next play.',
          backgroundColor: Colors.green[200], colorText: Colors.black87);
    } catch (e) {
      Get.snackbar('Cleanup Error', e.toString(),
          backgroundColor: Colors.red[300], colorText: Colors.white);
    } finally {
      isConnecting.value = false;
    }
  }
}
