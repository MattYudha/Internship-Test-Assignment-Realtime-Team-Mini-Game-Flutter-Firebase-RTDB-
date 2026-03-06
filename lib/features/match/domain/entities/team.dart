import 'tower.dart';

class Team {
  final String id;
  final int score;
  final Map<String, Tower> towers;

  Team({
    required this.id,
    required this.score,
    required this.towers,
  });

  factory Team.fromJson(String id, Map<dynamic, dynamic> json) {
    Map<String, Tower> parsedTowers = {};
    if (json['towers'] != null) {
      final towersMap = Map<String, dynamic>.from(json['towers']);
      towersMap.forEach((key, value) {
        parsedTowers[key] = Tower.fromJson(key, Map<dynamic, dynamic>.from(value));
      });
    }

    return Team(
      id: id,
      score: json['score'] ?? 0,
      towers: parsedTowers,
    );
  }
}
