import 'crossword_word.dart';

class CrosswordPuzzle {
  CrosswordPuzzle({
    required this.width,
    required this.height,
    required this.gridData,
    required this.words,
  });

  factory CrosswordPuzzle.fromJson(Map<String, dynamic> json) {
    final gridSource = json['gridData'] ?? json['grid'];
    final grid = (gridSource as List<dynamic>? ?? const [])
        .map((row) => row as String)
        .toList(growable: false);

    final clues = (json['clues'] as List<dynamic>? ?? const [])
        .map((item) => item as String)
        .toList(growable: false);

    final rawWords = (json['words'] as List<dynamic>? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);

    final parsedWords = <CrosswordWord>[];
    for (var i = 0; i < rawWords.length; i++) {
      final raw = rawWords[i];
      final inlineClue = (raw['clue'] as String?)?.trim();
      final listClue = i < clues.length ? clues[i] : null;
      final normalizedListClue =
          (listClue != null && listClue.trim().isNotEmpty)
          ? listClue.trim()
          : null;
      final chosenClue = inlineClue?.isNotEmpty == true
          ? inlineClue
          : normalizedListClue;
      parsedWords.add(CrosswordWord.fromJson(raw, clue: chosenClue));
    }

    final height = grid.length;
    final width = height > 0 ? grid.first.length : 0;

    return CrosswordPuzzle(
      width: width,
      height: height,
      gridData: grid,
      words: parsedWords,
    );
  }

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'gridData': gridData,
    'words': words.map((w) => w.toJson()).toList(growable: false),
    'clues': words.map((w) => w.clue).toList(growable: false),
  };

  final int width;
  final int height;
  final List<String> gridData;
  final List<CrosswordWord> words;
}
