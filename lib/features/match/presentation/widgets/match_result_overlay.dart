import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/match.dart';
import '../controllers/match_controller.dart';
import '../controllers/lobby_controller.dart';

class MatchResultOverlay extends StatelessWidget {
  final MatchData matchData;

  const MatchResultOverlay({super.key, required this.matchData});

  @override
  Widget build(BuildContext context) {
    final teamA = matchData.teams['teamA'];
    final teamB = matchData.teams['teamB'];

    final scoreA = teamA?.score ?? 0;
    final scoreB = teamB?.score ?? 0;

    int movesA = 0;
    int movesB = 0;
    for (var player in matchData.players.values) {
      if (player.team == 'teamA') movesA += player.stats.totalMoves;
      if (player.team == 'teamB') movesB += player.stats.totalMoves;
    }

    String winnerText;
    Color winnerColor;

    if (scoreA > scoreB) {
      winnerText = '🏆 Team A Wins!';
      winnerColor = const Color(0xFF448AFF);
    } else if (scoreB > scoreA) {
      winnerText = '🏆 Team B Wins!';
      winnerColor = const Color(0xFF00E5FF);
    } else {
      winnerText = '🤝 Match Drawn!';
      winnerColor = const Color(0xFFFFCA28);
    }

    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E), // Sleek Navy/Dark Gray
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: winnerColor.withOpacity(0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: winnerColor.withOpacity(0.3),
                blurRadius: 40,
                spreadRadius: -10,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MATCH ENDED',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white54,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                winnerText,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: winnerColor,
                  shadows: [Shadow(color: winnerColor.withOpacity(0.5), blurRadius: 10)],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Score Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildScore('TEAM A', scoreA, movesA, const Color(0xFF448AFF)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('VS', style: TextStyle(color: Colors.white30, fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  _buildScore('TEAM B', scoreB, movesB, const Color(0xFF00E5FF)),
                ],
              ),
              
              const SizedBox(height: 56),
              
              // Local cleanup only. Unassigned from Firebase Write redundancy.
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home_rounded, size: 24),
                  label: const Text('Return to Lobby', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1E1E2E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    // Clear session so reopening the app goes to lobby
                    await LobbyController.clearSession();
                    Get.delete<MatchController>();
                    Get.offAllNamed('/lobby');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScore(String teamName, int score, int moves, Color color) {
    return Column(
      children: [
        Text(teamName, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        Text(
          score.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.0),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$moves Moves',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
