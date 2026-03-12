enum JoinMatchStatus {
  created,
  joined,
  reconnected,
  lateJoinRejected,
  matchFull,
  teamFull,
  error
}

class JoinMatchResult {
  final JoinMatchStatus status;
  final String? matchId;
  final String? teamId;
  final String? message;

  const JoinMatchResult({
    required this.status,
    this.matchId,
    this.teamId,
    this.message,
  });
}
