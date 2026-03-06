import 'team.dart';
import 'player.dart';

class MatchData {
  final String id;
  final MatchMeta meta;
  final Map<String, Team> teams;
  final Map<String, Player> players;

  MatchData({
    required this.id,
    required this.meta,
    required this.teams,
    required this.players,
  });

  factory MatchData.fromJson(String id, Map<dynamic, dynamic> json) {
    final teamsMap = Map<String, dynamic>.from(json['teams'] ?? {});
    final playersMap = Map<String, dynamic>.from(json['players'] ?? {});

    Map<String, Team> parsedTeams = {};
    teamsMap.forEach((key, value) {
      parsedTeams[key] = Team.fromJson(key, Map<dynamic, dynamic>.from(value));
    });

    Map<String, Player> parsedPlayers = {};
    playersMap.forEach((key, value) {
      parsedPlayers[key] = Player.fromJson(key, Map<dynamic, dynamic>.from(value));
    });

    return MatchData(
      id: id,
      meta: MatchMeta.fromJson(Map<dynamic, dynamic>.from(json['meta'] ?? {})),
      teams: parsedTeams,
      players: parsedPlayers,
    );
  }
}

class MatchMeta {
  final String status;
  final int? startAt;
  final int? endAt;
  final int targetValue;
  final int poolIndexA;
  final int poolIndexB;

  MatchMeta({
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.targetValue,
    required this.poolIndexA,
    required this.poolIndexB,
  });

  factory MatchMeta.fromJson(Map<dynamic, dynamic> json) {
    return MatchMeta(
      status: json['status'] ?? 'waiting',
      startAt: json['startAt'],
      endAt: json['endAt'],
      targetValue: json['targetValue'] ?? 1000,
      poolIndexA: json['poolIndexA'] ?? 0,
      poolIndexB: json['poolIndexB'] ?? 0,
    );
  }
}
