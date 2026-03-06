class Tower {
  final String id;
  final int startValue;
  final String state; // 'available', 'claimed', 'solved'
  final String? claimedBy;
  final int? claimExpiresAt;
  final String? solvedBy;
  final int? movesTaken;
  final int? optimalMoves;

  Tower({
    required this.id,
    required this.startValue,
    required this.state,
    this.claimedBy,
    this.claimExpiresAt,
    this.solvedBy,
    this.movesTaken,
    this.optimalMoves,
  });

  factory Tower.fromJson(String id, Map<dynamic, dynamic> json) {
    return Tower(
      id: id,
      startValue: json['startValue'] ?? 0,
      state: json['state'] ?? 'available',
      claimedBy: json['claimedBy'],
      claimExpiresAt: json['claimExpiresAt'],
      solvedBy: json['solvedBy'],
      movesTaken: json['movesTaken'],
      optimalMoves: json['optimalMoves'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startValue': startValue,
      'state': state,
      'claimedBy': claimedBy,
      'claimExpiresAt': claimExpiresAt,
      'solvedBy': solvedBy,
      'movesTaken': movesTaken,
      'optimalMoves': optimalMoves,
    };
  }

  Tower copyWith({
    String? id,
    int? startValue,
    String? state,
    String? claimedBy,
    int? claimExpiresAt,
    String? solvedBy,
    int? movesTaken,
    int? optimalMoves,
  }) {
    return Tower(
      id: id ?? this.id,
      startValue: startValue ?? this.startValue,
      state: state ?? this.state,
      claimedBy: claimedBy ?? this.claimedBy,
      claimExpiresAt: claimExpiresAt ?? this.claimExpiresAt,
      solvedBy: solvedBy ?? this.solvedBy,
      movesTaken: movesTaken ?? this.movesTaken,
      optimalMoves: optimalMoves ?? this.optimalMoves,
    );
  }
}
