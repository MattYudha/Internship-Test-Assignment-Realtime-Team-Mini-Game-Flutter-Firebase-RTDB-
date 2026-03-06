class Player {
  final String uid;
  final String displayName;
  final String team; // 'teamA' or 'teamB'
  final int lastSeenAt;
  final PlayerStats stats;

  Player({
    required this.uid,
    required this.displayName,
    required this.team,
    required this.lastSeenAt,
    required this.stats,
  });

  factory Player.fromJson(String uid, Map<dynamic, dynamic> json) {
    return Player(
      uid: uid,
      displayName: json['displayName'] ?? 'Unknown',
      team: json['team'] ?? '',
      lastSeenAt: json['lastSeenAt'] ?? 0,
      stats: PlayerStats.fromJson(json['stats'] ?? {}),
    );
  }

  bool get isAFK {
    final now = DateTime.now().millisecondsSinceEpoch;
    // AFK threshold: 30 seconds
    return (now - lastSeenAt) > 30000;
  }
}

class PlayerStats {
  final int towersSolved;
  final int totalMoves;

  PlayerStats({
    required this.towersSolved,
    required this.totalMoves,
  });

  factory PlayerStats.fromJson(Map<dynamic, dynamic> json) {
    return PlayerStats(
      towersSolved: json['towersSolved'] ?? 0,
      totalMoves: json['totalMoves'] ?? 0,
    );
  }
}
