import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../domain/entities/match.dart';
import '../controllers/match_controller.dart';

class MatchResultOverlay extends StatelessWidget {
  final MatchData matchData;

  const MatchResultOverlay({super.key, required this.matchData});

  @override
  Widget build(BuildContext context) {
    final teamA = matchData.teams['teamA'];
    final teamB = matchData.teams['teamB'];

    final scoreA = teamA?.score ?? 0;
    final scoreB = teamB?.score ?? 0;

    String winnerText;
    Color winnerColor;

    if (scoreA > scoreB) {
      winnerText = '🏆 Team A Wins!';
      winnerColor = Colors.blue;
    } else if (scoreB > scoreA) {
      winnerText = '🏆 Team B Wins!';
      winnerColor = Colors.cyan;
    } else {
      winnerText = '🤝 Match Drawn!';
      winnerColor = Colors.amber;
    }

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20), // Dark green retro feel
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: winnerColor, width: 6),
            boxShadow: [
              BoxShadow(
                color: winnerColor.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MATCH ENDED!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                winnerText,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: winnerColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Score Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildScore('Team A', scoreA, Colors.blue),
                  const Text('VS', style: TextStyle(color: Colors.white54, fontSize: 20, fontWeight: FontWeight.bold)),
                  _buildScore('Team B', scoreB, Colors.cyan),
                ],
              ),
              
              const SizedBox(height: 48),
              
              // The critical fix: Local cleanup only. Unassigned from Firebase Write redundancy.
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home, size: 28),
                  label: const Text('Return to Lobby', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () {
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

  Widget _buildScore(String teamName, int score, Color color) {
    return Column(
      children: [
        Text(teamName, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        Text(
          score.toString(),
          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}
