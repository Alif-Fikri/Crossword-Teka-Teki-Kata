import 'package:hive_flutter/hive_flutter.dart';

import '../models/game_session.dart';
import '../services/crossword_api.dart';
import '../storage/hive_boxes.dart';

class CrosswordRepository {
  CrosswordRepository({
    CrosswordApi? api,
    Box<dynamic>? settingsBox,
    Box<dynamic>? sessionBox,
  }) : _api = api ?? CrosswordApi(),
       _settingsBox = settingsBox ?? HiveBoxes.settingsBox,
       _sessionBox = sessionBox ?? HiveBoxes.sessionBox;

  static const _activeSessionKey = 'active_session';
  static const _boardEntriesKey = 'board_entries';
  static const _elapsedSecondsKey = 'elapsed_seconds';
  static const _currentWordIndexKey = 'current_word_index';
  static const _hintsUsageKey = 'hints_usage';

  final CrosswordApi _api;
  final Box<dynamic> _settingsBox;
  final Box<dynamic> _sessionBox;

  Future<GameSession> startSession(String playerName) async {
    final session = await _api.startSession(playerName);
    _settingsBox.put('player_name', playerName);

    _sessionBox
      ..put(_activeSessionKey, session.toJson())
      ..put(
        _boardEntriesKey,
        List.generate(
          session.puzzle.height,
          (_) => List.filled(session.puzzle.width, ''),
        ),
      )
      ..put(_elapsedSecondsKey, 0)
      ..put(_currentWordIndexKey, 0)
      ..put(_hintsUsageKey, <String, int>{});

    return session;
  }

  Future<GameSession?> loadActiveSession() async {
    final map = _sessionBox.get(_activeSessionKey);
    if (map is Map) {
      return GameSession.fromJson(map);
    }
    return null;
  }

  Future<void> saveSession(GameSession session) async {
    _sessionBox.put(_activeSessionKey, session.toJson());
  }

  Future<void> clearSession() async {
    await _sessionBox.deleteAll({
      _activeSessionKey,
      _boardEntriesKey,
      _elapsedSecondsKey,
      _currentWordIndexKey,
      _hintsUsageKey,
    });
  }

  List<List<String>> loadBoardEntries(int height, int width) {
    final raw = _sessionBox.get(_boardEntriesKey);
    if (raw is List) {
      return raw
          .map<List<String>>(
            (row) => row is List
                ? row.map<String>((v) => '$v').toList(growable: false)
                : List.filled(width, ''),
          )
          .toList(growable: false);
    }
    return List.generate(height, (_) => List.filled(width, ''));
  }

  Future<void> saveBoardEntries(List<List<String>> entries) async {
    final copy = entries
        .map((row) => row.map((value) => value).toList(growable: false))
        .toList(growable: false);
    await _sessionBox.put(_boardEntriesKey, copy);
  }

  int loadElapsedSeconds() {
    final raw = _sessionBox.get(_elapsedSecondsKey);
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Future<void> saveElapsedSeconds(int seconds) async {
    await _sessionBox.put(_elapsedSecondsKey, seconds);
  }

  int loadCurrentWordIndex() {
    final raw = _sessionBox.get(_currentWordIndexKey);
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Future<void> saveCurrentWordIndex(int index) async {
    await _sessionBox.put(_currentWordIndexKey, index);
  }

  Map<int, int> loadHintsUsage() {
    final raw = _sessionBox.get(_hintsUsageKey);
    if (raw is Map) {
      return raw.map((key, value) {
        final parsedKey = int.tryParse('$key') ?? 0;
        final parsedValue = value is int ? value : int.tryParse('$value') ?? 0;
        return MapEntry(parsedKey, parsedValue);
      });
    }
    return {};
  }

  Future<void> saveHintsUsage(Map<int, int> usage) async {
    final serialized = usage.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    await _sessionBox.put(_hintsUsageKey, serialized);
  }

  String? loadLastPlayerName() {
    final value = _settingsBox.get('player_name');
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return null;
  }

  Future<void> dispose() async {
    _api.dispose();
  }
}
