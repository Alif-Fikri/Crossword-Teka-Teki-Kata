import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/crossword_puzzle.dart';
import '../models/game_session.dart';

class CrosswordApi {
  CrosswordApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? defaultBaseUrl;

  static const defaultBaseUrl = 'http://127.0.0.1:8000';

  final http.Client _client;
  final String _baseUrl;

  Uri _url(String path) => Uri.parse('$_baseUrl$path');

  Future<GameSession> startSession(String playerName) async {
    final response = await _client.post(
      _url('/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'player_name': playerName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Gagal memulai permainan (${response.statusCode})');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return GameSession.fromJson(map);
  }

  Future<CrosswordPuzzle> fetchPuzzle() async {
    final response = await _client.get(_url('/puzzle'));
    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil puzzle (${response.statusCode})');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return CrosswordPuzzle.fromJson(map);
  }

  void dispose() {
    _client.close();
  }
}
