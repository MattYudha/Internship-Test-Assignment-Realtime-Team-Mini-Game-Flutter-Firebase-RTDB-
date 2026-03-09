import 'dart:async';
import 'dart:math';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
import '../../domain/repositories/match_repository.dart';
import '../../domain/entities/match.dart';
import '../../domain/usecases/bfs_solver.dart';

// ---------------------------------------------------------------------------
// BotService
//
// Implements the professor's specification:
//  1. Bot registration: each bot is written to /players in Firebase as if a
//     real device joined, using the MatchRepository.addBot() transaction.
//  2. Loop-based simulation using async while-loops (NOT stream listeners)
//     so each bot acts independently on its own cadence.
//  3. Skill levels:
//     - 'optimal': bot uses BfsSolver result directly, short Jitter (1–2 s).
//     - 'random' : bot adds 0–3 penalty moves and waits longer (3–6 s) to
//       simulate a confused human player.
//  4. Jitter before EVERY claim transaction to prevent RTDB transaction
//     overload when many bots fire at the same instant.
//  5. Host-only: spawning / starting / stopping is controlled from the
//     DebugBotPanel, which is only visible to the match host.
// ---------------------------------------------------------------------------

/// Represents a single bot's runtime state.
class _BotState {
  final String uid;
  final String teamId;
  final String skillLevel; // 'optimal' | 'random'

  const _BotState({
    required this.uid,
    required this.teamId,
    required this.skillLevel,
  });
}

class BotService extends GetxController {
  final MatchRepository _matchRepo;
  final String matchId;

  BotService(this._matchRepo, this.matchId);

  // ---- Observable state for reactive UI ----
  final RxMap<String, _BotState> _bots = <String, _BotState>{}.obs;
  final RxBool _isRunning = false.obs;

  // ---- Latest match snapshot (fed from MatchController) ----
  MatchData? _latestMatch;

  final Random _rnd = Random();
  final Uuid _uuid = const Uuid();

  // ---- Public reactive getters ----
  bool get isRunning => _isRunning.value;
  int get botCount => _bots.length;

  /// Called by MatchController on every RTDB stream event.
  void updateMatchState(MatchData data) => _latestMatch = data;

  // --------------------------------------------------------------------------
  // Spawn a bot: register it in Firebase, then kick off its loop if running.
  // --------------------------------------------------------------------------
  Future<void> spawnBot(String teamId, String skillLevel) async {
    if (_bots.length >= 6) return; // Hard cap: max 6 bots total

    final String botUid = 'bot_${_uuid.v4().substring(0, 8)}';
    final String botName = _botName();

    // Register bot into /players node via repository transaction
    await _matchRepo.addBot(matchId, teamId, botUid, botName);

    final state = _BotState(uid: botUid, teamId: teamId, skillLevel: skillLevel);
    _bots[botUid] = state;

    // If simulation is already live, start this bot's loop immediately
    if (_isRunning.value) {
      _runLoop(botUid);
    }
  }

  // --------------------------------------------------------------------------
  // Start / Stop simulation
  // --------------------------------------------------------------------------
  void startSimulation() {
    if (_isRunning.value) return;
    _isRunning.value = true;
    for (final uid in _bots.keys) {
      _runLoop(uid);
    }
  }

  void stopSimulation() {
    _isRunning.value = false;
    // Loops will exit on the next iteration check
  }

  // ---- Active loop registry to prevent double-spawning bot logic ----
  final Set<String> _activeLoops = {};

  // --------------------------------------------------------------------------
  // The core bot loop (prof's spec: while-loop, not stream listener)
  // --------------------------------------------------------------------------
  Future<void> _runLoop(String botUid) async {
    if (_activeLoops.contains(botUid)) {
      print('[Bot $botUid] Loop already active. Ignoring double spawn.');
      return;
    }
    
    _activeLoops.add(botUid);
    print('[Bot $botUid] Starting simulation loop.');

    try {
      while (_isRunning.value) {
        final bot = _bots[botUid];
        if (bot == null) break;

        // --- Heartbeat: keep bot alive in match roster ---
        await _matchRepo.updateHeartbeat(matchId, botUid);

        // --- Wait for a valid running match ---
        final match = _latestMatch;
        if (match == null || match.meta.status != 'running') {
          print('[Bot ${bot.uid}] Waiting for match to start (status: ${match?.meta.status})...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        final team = match.teams[bot.teamId];
        if (team == null) {
          print('[Bot ${bot.uid}] Team ${bot.teamId} not found in match state!');
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        // --- Find an available tower (including expired claims) ---
        final now = DateTime.now().millisecondsSinceEpoch;
        final available = team.towers.values.where((t) {
          if (t.state == 'available') return true;
          // Steal a tower whose claim window has expired
          if (t.state == 'claimed' &&
              t.claimExpiresAt != null &&
              t.claimExpiresAt! < now) {
            print('[Bot ${bot.uid}] Found EXPIRED claimed tower: ${t.id}');
            return true;
          }
          return false;
        }).toList();

        if (available.isEmpty) {
          // Nothing to do right now — check again in 1 s
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        // Pick a random tower from available pool
        final target = available[_rnd.nextInt(available.length)];
        print('[Bot ${bot.uid}] Targeting tower ${target.id} (val: ${target.startValue})');

        // --- JITTER before claim (prevents RTDB transaction bomb) ---
        // HUMANIZATION: Bots now actually "look" at the screen before picking
        final claimJitter = 1500 + _rnd.nextInt(2500); // 1.5 - 4 seconds to decide
        await Future.delayed(Duration(milliseconds: claimJitter));
        if (!_isRunning.value) break;

        // --- Attempt atomic claim ---
        final claimed = await _matchRepo.claimTower(matchId, bot.teamId, target.id, botUid);
        if (!claimed) {
          print('[Bot $botUid] -> CLAIM FAILED: Beat by another player or rules rejected.');
          continue;
        }
        print('[Bot $botUid] -> CLAIM SUCCESS on ${target.id}');

        // --- BFS computation on a background isolate (compute) ---
        final int targetValue = match.meta.targetValue;
        final int optimalMoves = await BfsSolver.getOptimalMoves(target.startValue, targetValue);

        // --- PROF Feedback: Handle Unreachable Path ---
        if (optimalMoves < 0) {
          print('[Bot $botUid] -> UNREACHABLE TOWER. Releasing ${target.id}.');
          await _matchRepo.releaseTower(matchId, bot.teamId, target.id);
          await Future.delayed(const Duration(seconds: 2)); // cooldown after fail
          continue;
        }

        // --- Apply skill level ---
        int reportedMoves;
        int solveDelayMs;

        if (bot.skillLevel == 'optimal') {
          // Pintar: use exact BFS answer, short delay
          reportedMoves = optimalMoves;
          solveDelayMs = 2000 + _rnd.nextInt(2000); // 2-4 s to solve
        } else {
          // Bodoh (random): add 0–3 penalty moves, much longer delay
          final penalty = _rnd.nextInt(4); // 0, 1, 2, or 3
          reportedMoves = optimalMoves + penalty;
          // HUMANIZATION: Really slow them down.
          // Base 5-8 seconds + 1 sec per move penalty
          solveDelayMs = 5000 + _rnd.nextInt(3000) + (penalty * 1000);
        }

        // --- JITTER: simulate solve time ---
        await Future.delayed(Duration(milliseconds: solveDelayMs));
        if (!_isRunning.value) {
          // Stopped mid-solve — release the tower for human players
          await _matchRepo.releaseTower(matchId, bot.teamId, target.id);
          break;
        }

        // --- Submit solve transaction ---
        final solveSuccess = await _matchRepo.solveTower(
          matchId,
          bot.teamId,
          target.id,
          botUid,
          reportedMoves,
          optimalMoves,
        );

        if (solveSuccess) {
           print('[Bot $botUid] -> SOLVE SUCCESS on ${target.id} ($reportedMoves moves)');
        } else {
           print('[Bot $botUid] -> SOLVE FAILED/REJECTED on ${target.id}');
        }

        // Small cooldown between actions (prevents a single fast bot from
        // monopolising all towers before others get a chance)
        await Future.delayed(Duration(milliseconds: 500 + _rnd.nextInt(500)));
      }
    } finally {
      _activeLoops.remove(botUid);
      print('[Bot $botUid] Simulation loop exited naturally.');
    }
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------
  static const _adjectives = ['Alpha', 'Bravo', 'Delta', 'Echo', 'Foxtrot', 'Gamma', 'Sigma', 'Omega'];
  static const _nouns = ['Ghost', 'Hawk', 'Nova', 'Pulse', 'Storm', 'Titan', 'Vex', 'Zephyr'];

  String _botName() {
    final adj = _adjectives[_rnd.nextInt(_adjectives.length)];
    final noun = _nouns[_rnd.nextInt(_nouns.length)];
    return '[$adj $noun]';
  }

  @override
  void onClose() {
    _isRunning.value = false;
    super.onClose();
  }
}
