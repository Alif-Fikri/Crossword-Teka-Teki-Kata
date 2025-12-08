import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/models/crossword_word.dart';
import '../data/models/game_session.dart';
import '../data/repositories/crossword_repository.dart';
import 'crossword_board.dart';

enum WordDirection { across, down }

class CrosswordController extends ChangeNotifier {
  CrosswordController({required this.repository});

  final CrosswordRepository repository;

  GameSession? _session;
  List<List<BoardCell>> _board = const [];
  CellPosition? _selectedCell;
  WordDirection _activeDirection = WordDirection.across;
  int _currentWordIndex = 0;
  bool _isLoading = false;
  String? _error;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  final Map<int, int> _hintsUsed = {};
  final Random _random = Random();

  GameSession? get session => _session;
  List<List<BoardCell>> get board => _board;
  CellPosition? get selectedCell => _selectedCell;
  WordDirection get activeDirection => _activeDirection;
  int get currentWordIndex => _currentWordIndex;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Duration get elapsed => _elapsed;
  int get hintsRemainingForCurrentWord {
    final word = currentWord;
    if (word == null) return 0;
    final allowance = _hintAllowanceFor(word);
    final used = _hintsUsed[_currentWordIndex] ?? 0;
    return (allowance - used).clamp(0, allowance);
  }

  int get totalHintsForCurrentWord {
    final word = currentWord;
    if (word == null) return 0;
    return _hintAllowanceFor(word);
  }

  int get hintsUsedForCurrentWord => _hintsUsed[_currentWordIndex] ?? 0;
  bool get isPuzzleSolved {
    if (_board.isEmpty) return false;
    for (final row in _board) {
      for (final cell in row) {
        if (cell.isBlock) continue;
        if (cell.entry.isEmpty) {
          return false;
        }
        if (cell.entry.toUpperCase() != cell.solution.toUpperCase()) {
          return false;
        }
      }
    }
    return true;
  }

  List<CellPosition> get activeWordCells {
    final word = currentWord;
    if (word == null) return const [];
    return List.unmodifiable(_cellsForWord(word));
  }

  CrosswordWord? get currentWord {
    if (_session == null) return null;
    final words = _session!.puzzle.words;
    if (_currentWordIndex < 0 || _currentWordIndex >= words.length) {
      return null;
    }
    return words[_currentWordIndex];
  }

  Future<bool> loadExistingSession() async {
    _error = null;
    _setLoading(true);
    try {
      final loaded = await repository.loadActiveSession();
      if (loaded == null) {
        return false;
      }
      final savedEntries = repository.loadBoardEntries(
        loaded.puzzle.height,
        loaded.puzzle.width,
      );
      final elapsedSeconds = repository.loadElapsedSeconds();
      final index = repository.loadCurrentWordIndex();
      final hintsUsage = repository.loadHintsUsage();
      _applySession(
        loaded,
        entries: savedEntries,
        elapsed: Duration(seconds: elapsedSeconds),
        currentWordIndex: index,
        hintsUsage: hintsUsage,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> startNewSession(String playerName) async {
    _error = null;
    _setLoading(true);
    try {
      final session = await repository.startSession(playerName);
      final entries = repository.loadBoardEntries(
        session.puzzle.height,
        session.puzzle.width,
      );
      final hintsUsage = repository.loadHintsUsage();
      _applySession(
        session,
        entries: entries,
        elapsed: Duration.zero,
        currentWordIndex: 0,
        hintsUsage: hintsUsage,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> clearSession() async {
    await repository.clearSession();
    _timer?.cancel();
    _session = null;
    _board = const [];
    _selectedCell = null;
    _elapsed = Duration.zero;
    _hintsUsed.clear();
    notifyListeners();
  }

  void selectCell(CellPosition position) {
    if (_board.isEmpty) return;
    final cell = _cellAt(position);
    if (cell == null || cell.isBlock) {
      return;
    }

    final across = cell.acrossWordIndex;
    final down = cell.downWordIndex;

    if (_activeDirection == WordDirection.across && across != null) {
      _currentWordIndex = across;
    } else if (_activeDirection == WordDirection.down && down != null) {
      _currentWordIndex = down;
    } else if (across != null) {
      _activeDirection = WordDirection.across;
      _currentWordIndex = across;
    } else if (down != null) {
      _activeDirection = WordDirection.down;
      _currentWordIndex = down;
    }

    _selectedCell = position;
    repository.saveCurrentWordIndex(_currentWordIndex);
    notifyListeners();
  }

  void toggleDirection() {
    if (_board.isEmpty) return;
    _activeDirection = _activeDirection == WordDirection.across
        ? WordDirection.down
        : WordDirection.across;
    final cell = _selectedCell != null ? _cellAt(_selectedCell!) : null;
    if (cell != null) {
      final targetIndex = _activeDirection == WordDirection.across
          ? cell.acrossWordIndex
          : cell.downWordIndex;
      if (targetIndex != null) {
        _currentWordIndex = targetIndex;
      }
    }
    repository.saveCurrentWordIndex(_currentWordIndex);
    notifyListeners();
  }

  void handleInput(String input) {
    if (input.isEmpty || _selectedCell == null) return;
    final cell = _cellAt(_selectedCell!);
    if (cell == null || cell.isBlock) return;
    final letter = input.substring(input.length - 1).toUpperCase();
    if (!_isValidCharacter(letter)) return;

    cell.entry = letter;
    repository.saveBoardEntries(_exportEntries());
    notifyListeners();
    _moveSelection(forward: true);
  }

  void handleBackspace() {
    if (_selectedCell == null) return;
    final cell = _cellAt(_selectedCell!);
    if (cell == null || cell.isBlock) return;
    if (cell.entry.isNotEmpty) {
      cell.entry = '';
      repository.saveBoardEntries(_exportEntries());
      notifyListeners();
    }
    _moveSelection(forward: false, skipClear: true);
  }

  void nextWord() {
    if (_session == null) return;
    final words = _session!.puzzle.words;
    if (words.isEmpty) return;
    _currentWordIndex = (_currentWordIndex + 1) % words.length;
    _activeDirection = words[_currentWordIndex].isAcross
        ? WordDirection.across
        : WordDirection.down;
    _moveToWord(_currentWordIndex);
  }

  void previousWord() {
    if (_session == null) return;
    final words = _session!.puzzle.words;
    if (words.isEmpty) return;
    _currentWordIndex = (_currentWordIndex - 1 + words.length) % words.length;
    _activeDirection = words[_currentWordIndex].isAcross
        ? WordDirection.across
        : WordDirection.down;
    _moveToWord(_currentWordIndex);
  }

  bool revealHint() {
    final word = currentWord;
    if (word == null) return false;
    final allowance = _hintAllowanceFor(word);
    final used = _hintsUsed[_currentWordIndex] ?? 0;
    if (used >= allowance) {
      return false;
    }

    final cells = _cellsForWord(word);
    final candidates = cells.where((pos) {
      final cell = _cellAt(pos);
      if (cell == null || cell.isBlock) return false;
      return cell.entry.toUpperCase() != cell.solution.toUpperCase();
    }).toList();

    if (candidates.isEmpty) {
      return false;
    }

    final target = candidates[_random.nextInt(candidates.length)];
    final cell = _cellAt(target);
    if (cell == null) return false;
    cell.entry = cell.solution;
    _selectedCell = target;
    _hintsUsed[_currentWordIndex] = used + 1;
    repository.saveBoardEntries(_exportEntries());
    repository.saveHintsUsage(_hintsUsed);
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- internal helpers ---

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _applySession(
    GameSession session, {
    required List<List<String>> entries,
    required Duration elapsed,
    required int currentWordIndex,
    required Map<int, int> hintsUsage,
  }) {
    _session = session;
    _elapsed = elapsed;
    _currentWordIndex = currentWordIndex;
    _activeDirection = session.puzzle.words[currentWordIndex].isAcross
        ? WordDirection.across
        : WordDirection.down;
    _buildBoard(session, entries);
    _hintsUsed
      ..clear()
      ..addAll(hintsUsage);
    _startTimer(from: elapsed);
    _moveToWord(_currentWordIndex);
    notifyListeners();
  }

  void _buildBoard(GameSession session, List<List<String>> savedEntries) {
    final height = session.puzzle.height;
    final width = session.puzzle.width;
    final board = List.generate(
      height,
      (row) => List.generate(
        width,
        (col) => BoardCell(row: row, col: col, isBlock: true),
      ),
    );

    for (var i = 0; i < session.puzzle.words.length; i++) {
      final word = session.puzzle.words[i];
      final letters = word.normalizedAnswer.split('');
      for (var j = 0; j < letters.length; j++) {
        final row = word.row + (word.isDown ? j : 0);
        final col = word.col + (word.isAcross ? j : 0);
        final existing = board[row][col];
        final isFirst = j == 0;

        String entry = '';
        if (row < savedEntries.length && col < savedEntries[row].length) {
          entry = savedEntries[row][col];
        }
        if (isFirst && entry.isEmpty) {
          entry = letters[j];
        }

        board[row][col] = BoardCell(
          row: row,
          col: col,
          isBlock: false,
          solution: letters[j],
          acrossWordIndex: word.isAcross ? i : existing.acrossWordIndex,
          downWordIndex: word.isDown ? i : existing.downWordIndex,
          entry: entry,
          isFirstLetter: isFirst,
        );
      }
    }

    _board = board;
  }

  void _moveSelection({required bool forward, bool skipClear = false}) {
    final word = currentWord;
    if (word == null) return;
    final cells = _cellsForWord(word);
    if (cells.isEmpty) return;

    var index = _selectedCell != null
        ? cells.indexWhere((pos) => pos == _selectedCell)
        : -1;

    if (index == -1) {
      index = 0;
    } else {
      index += forward ? 1 : -1;
    }

    if (index < 0 || index >= cells.length) {
      if (forward) {
        nextWord();
      } else {
        previousWord();
      }
      return;
    }

    _selectedCell = cells[index];
    if (!skipClear) {
      final cell = _cellAt(_selectedCell!);
      if (cell != null && cell.entry.isEmpty) {
        repository.saveCurrentWordIndex(_currentWordIndex);
      }
    }
    notifyListeners();
  }

  void _moveToWord(int wordIndex) {
    final word = currentWord;
    if (word == null) return;
    final cells = _cellsForWord(word);
    if (cells.isEmpty) return;
    _selectedCell = cells.firstWhere(
      (pos) => (_cellAt(pos)?.entry.isEmpty ?? true),
      orElse: () => cells.first,
    );
    repository.saveCurrentWordIndex(_currentWordIndex);
    notifyListeners();
  }

  List<CellPosition> _cellsForWord(CrosswordWord word) {
    final cells = <CellPosition>[];
    for (var i = 0; i < word.length; i++) {
      final row = word.row + (word.isDown ? i : 0);
      final col = word.col + (word.isAcross ? i : 0);
      cells.add(CellPosition(row, col));
    }
    return cells;
  }

  BoardCell? _cellAt(CellPosition position) {
    if (_board.isEmpty) return null;
    if (position.row < 0 || position.row >= _board.length) return null;
    if (position.col < 0 || position.col >= _board[position.row].length) {
      return null;
    }
    return _board[position.row][position.col];
  }

  bool _isValidCharacter(String char) {
    final pattern = RegExp(r'^[A-Z0-9/]$');
    return pattern.hasMatch(char);
  }

  List<List<String>> _exportEntries() {
    return _board
        .map((row) => row.map((cell) => cell.entry).toList(growable: false))
        .toList(growable: false);
  }

  int _hintAllowanceFor(CrosswordWord word) {
    if (word.length <= 4) return 1;
    if (word.length <= 8) return 2;
    return 3;
  }

  void _startTimer({required Duration from}) {
    _timer?.cancel();
    _elapsed = from;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      repository.saveElapsedSeconds(_elapsed.inSeconds);
      notifyListeners();
    });
  }
}
