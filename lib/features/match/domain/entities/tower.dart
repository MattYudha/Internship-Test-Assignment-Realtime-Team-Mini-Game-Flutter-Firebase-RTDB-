class Tower {
  final String id;
  final int startValue;
  final String state; // 'available', 'claimed', 'solved'
  final String? claimedBy;
  final int? claimExpiresAt;
  final String? solvedBy;
  final int? solvedAt; // Timestamp ms — used to find most recently solved (car position)
  final int? movesTaken;
  final int? optimalMoves;

  Tower({
    required this.id,
    required this.startValue,
    required this.state,
    this.claimedBy,
    this.claimExpiresAt,
    this.solvedBy,
    this.solvedAt,
    this.movesTaken,
    this.optimalMoves,
  });

  factory Tower.fromJson(String id, Map<dynamic, dynamic> json) {
    return Tower(
      id: id,
      startValue: json['startValue'] ?? 0,
      state: json['state'] ?? 'available',
      claimedBy: json['claimedBy'],
      claimExpiresAt: json['claimExpiresAt'] is int ? json['claimExpiresAt'] as int : null,
      solvedBy: json['solvedBy'],
      solvedAt: json['solvedAt'] is int ? json['solvedAt'] as int : null,
      movesTaken: json['movesTaken'] is int ? json['movesTaken'] as int : null,
      optimalMoves: json['optimalMoves'] is int ? json['optimalMoves'] as int : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startValue': startValue,
      'state': state,
      'claimedBy': claimedBy,
      'claimExpiresAt': claimExpiresAt,
      'solvedBy': solvedBy,
      'solvedAt': solvedAt,
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
    int? solvedAt,
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
      solvedAt: solvedAt ?? this.solvedAt,
      movesTaken: movesTaken ?? this.movesTaken,
      optimalMoves: optimalMoves ?? this.optimalMoves,
    );
  }
}
