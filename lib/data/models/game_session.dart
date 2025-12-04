import 'crossword_puzzle.dart';

class GameSession {
  GameSession({
    required this.sessionId,
    required this.playerName,
    required this.startedAt,
    required this.puzzle,
  });

  factory GameSession.fromJson(Map<dynamic, dynamic> raw) {
    final json = Map<String, dynamic>.from(raw);
    final puzzleValue = json['puzzle'];
    final puzzleMap = puzzleValue is Map<String, dynamic>
        ? puzzleValue
        : puzzleValue is Map
        ? Map<String, dynamic>.from(puzzleValue)
        : <String, dynamic>{};

    return GameSession(
      sessionId:
          json['session_id'] as String? ?? json['sessionId'] as String? ?? '',
      playerName:
          json['player_name'] as String? ?? json['playerName'] as String? ?? '',
      startedAt:
          DateTime.tryParse(
            json['started_at'] as String? ?? json['startedAt'] as String? ?? '',
          ) ??
          DateTime.now(),
      puzzle: CrosswordPuzzle.fromJson(puzzleMap),
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'player_name': playerName,
    'started_at': startedAt.toUtc().toIso8601String(),
    'puzzle': puzzle.toJson(),
  };

  final String sessionId;
  final String playerName;
  final DateTime startedAt;
  final CrosswordPuzzle puzzle;
}
