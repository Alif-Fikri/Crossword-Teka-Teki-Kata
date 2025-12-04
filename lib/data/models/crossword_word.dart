import 'package:collection/collection.dart';

class CrosswordWord {
  CrosswordWord({
    required this.answer,
    required this.row,
    required this.col,
    required this.direction,
    required this.clue,
  }) : normalizedAnswer = _normalizeAnswer(answer);

  factory CrosswordWord.fromJson(Map<String, dynamic> json, {String? clue}) {
    return CrosswordWord(
      answer: _parseString(json['word']) ?? _parseString(json['answer']) ?? '',
      row: _parseInt(json['row']),
      col: _parseInt(json['col']),
      direction:
          _parseString(json['dir']) ??
          _parseString(json['direction']) ??
          'across',
      clue: clue ?? _parseString(json['clue']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'word': answer,
    'row': row,
    'col': col,
    'dir': direction,
    'clue': clue,
  };

  static String _normalizeAnswer(String raw) {
    final cleaned = (raw).trim().toUpperCase();
    return cleaned
        .split('')
        .mapIndexed((index, char) => char == '_' ? '/' : char)
        .join();
  }

  static String? _parseString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  final String answer;
  final String normalizedAnswer;
  final int row;
  final int col;
  final String direction;
  final String clue;

  bool get isAcross => direction.toLowerCase() == 'across';
  bool get isDown => direction.toLowerCase() == 'down';
  int get length => normalizedAnswer.length;
}
