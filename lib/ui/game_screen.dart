import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/crossword_board.dart';
import '../state/crossword_controller.dart';
import '../utils/formatters.dart';
import 'start_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  static const routeName = '/game';

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  String _typedClue = '';
  String? _currentFullClue;
  Timer? _clueAnimationTimer;
  bool _completionSheetVisible = false;
  double _zoomLevel = 1.0;
  int? _lastWordIndex;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestKeyboard();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _inputFocusNode.dispose();
    _inputController.dispose();
    _clueAnimationTimer?.cancel();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _requestKeyboard() {
    if (mounted) {
      if (!_inputFocusNode.hasFocus) {
        FocusScope.of(context).requestFocus(_inputFocusNode);
      }
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }
  }

  void _handleCellTap(CrosswordController controller, int row, int col) {
    controller.selectCell(CellPosition(row, col));
    _requestKeyboard();
    _scrollToActiveWord(controller);
  }

  void _scrollToActiveWord(CrosswordController controller) {
    final currentWord = controller.currentWord;
    if (currentWord == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rows = controller.board.length;
      final cols = controller.board.isNotEmpty
          ? controller.board.first.length
          : 0;
      if (rows == 0 || cols == 0) return;

      final minCellSize = 24.0;
      final screenWidth = MediaQuery.of(context).size.width - 24;
      final maxCellSize = (screenWidth - 24) / cols;
      final baseCellSize = maxCellSize.clamp(minCellSize, 40.0);
      final cellSize = baseCellSize * _zoomLevel;

      final wordLength = currentWord.length;
      final midOffset = wordLength ~/ 2;

      final targetRow = currentWord.row + (currentWord.isDown ? midOffset : 0);
      final targetCol =
          currentWord.col + (currentWord.isAcross ? midOffset : 0);

      if (_horizontalScrollController.hasClients) {
        final maxScrollH = _horizontalScrollController.position.maxScrollExtent;
        final targetScrollH =
            (targetCol * cellSize - screenWidth / 2 + cellSize / 2).clamp(
              0.0,
              maxScrollH,
            );
        _horizontalScrollController.animateTo(
          targetScrollH,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }

      if (_verticalScrollController.hasClients) {
        final screenHeight = MediaQuery.of(context).size.height;
        final maxScrollV = _verticalScrollController.position.maxScrollExtent;
        final targetScrollV = (targetRow * cellSize - screenHeight / 3).clamp(
          0.0,
          maxScrollV,
        );
        _verticalScrollController.animateTo(
          targetScrollV,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _handleTextChange(String value) {
    if (value.isEmpty) return;
    _handleCharacterInput(value.substring(value.length - 1));
    _inputController.clear();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      context.read<CrosswordController>().handleBackspace();
      return true;
    }
    return false;
  }

  void _handleCharacterInput(String value) {
    if (value.isEmpty) return;
    context.read<CrosswordController>().handleInput(value);
  }

  void _handleHintPressed(CrosswordController controller) {
    final success = controller.revealHint();
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Satu huruf otomatis terisi.'
                : 'Bantuan untuk kata ini sudah habis.',
          ),
        ),
      );
    _requestKeyboard();
  }

  Future<void> _confirmResetGame(CrosswordController controller) async {
    final shouldReset =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset permainan?'),
            content: const Text(
              'Semua jawaban dan progres saat ini akan dihapus. Puzzle terbaru akan dimuat ulang.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldReset) return;
    await controller.clearSession();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const StartScreen()));
  }

  void _navigateBack(BuildContext context) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const StartScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CrosswordController>();
    final board = controller.board;
    final clueText = _formattedClue(controller.currentWord?.clue);
    _ensureClueAnimation(clueText);

    if (_lastWordIndex != controller.currentWordIndex) {
      _lastWordIndex = controller.currentWordIndex;
      _scrollToActiveWord(controller);
    }
    final displayedClue = _typedClue.isEmpty ? clueText : _typedClue;
    final hintsRemaining = controller.hintsRemainingForCurrentWord;
    final hintsTotal = controller.totalHintsForCurrentWord;
    _maybeShowCompletion(controller);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new),
                    onPressed: () => _navigateBack(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          formatDuration(controller.elapsed),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (controller.currentWord != null)
                          Text(
                            'Kata ${controller.currentWordIndex + 1}/${controller.session?.puzzle.words.length ?? 0}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _HintButton(
                    hintsRemaining: hintsRemaining,
                    hintsTotal: hintsTotal,
                    onPressed: hintsRemaining > 0
                        ? () => _handleHintPressed(controller)
                        : null,
                  ),
                  const SizedBox(width: 6),
                  _ZoomControls(
                    zoomLevel: _zoomLevel,
                    onZoomIn: () {
                      setState(() {
                        _zoomLevel = (_zoomLevel + 0.2).clamp(0.7, 2.0);
                      });
                    },
                    onZoomOut: () {
                      setState(() {
                        _zoomLevel = (_zoomLevel - 0.2).clamp(0.7, 2.0);
                      });
                    },
                  ),
                  IconButton(
                    tooltip: 'Reset permainan',
                    icon: const Icon(Icons.restart_alt_rounded),
                    onPressed: () => _confirmResetGame(controller),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: board.isEmpty
                      ? const CircularProgressIndicator()
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final rows = board.length;
                            final cols = board.first.length;
                            const minCellSize = 24.0;
                            final maxCellSize =
                                (constraints.maxWidth - 24) / cols;
                            final baseCellSize = maxCellSize.clamp(
                              minCellSize,
                              40.0,
                            );
                            final cellSize = baseCellSize * _zoomLevel;

                            final gridWidth = cellSize * cols;
                            final gridHeight = cellSize * rows;
                            final wordCells = controller.activeWordCells;

                            return SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                controller: _verticalScrollController,
                                scrollDirection: Axis.vertical,
                                child: SizedBox(
                                  width: gridWidth,
                                  height: gridHeight,
                                  child: Stack(
                                    children: [
                                      GridView.builder(
                                        padding: EdgeInsets.zero,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: cols,
                                              childAspectRatio: 1,
                                            ),
                                        itemCount: rows * cols,
                                        itemBuilder: (context, index) {
                                          final row = index ~/ cols;
                                          final col = index % cols;
                                          final cell = board[row][col];
                                          final isSelected =
                                              controller.selectedCell ==
                                              CellPosition(row, col);
                                          final isActive = wordCells.contains(
                                            CellPosition(row, col),
                                          );
                                          return _CrosswordCellWidget(
                                            cell: cell,
                                            isSelected: isSelected,
                                            isActive: isActive,
                                            cellSize: cellSize,
                                            onTap: () => _handleCellTap(
                                              controller,
                                              row,
                                              col,
                                            ),
                                          );
                                        },
                                      ),
                                      Align(
                                        alignment: Alignment.center,
                                        child: Offstage(
                                          offstage: false,
                                          child: SizedBox(
                                            width: 1,
                                            height: 1,
                                            child: TextField(
                                              controller: _inputController,
                                              focusNode: _inputFocusNode,
                                              autofocus: true,
                                              enableSuggestions: false,
                                              autocorrect: false,
                                              maxLength: 1,
                                              keyboardType: TextInputType.text,
                                              textCapitalization:
                                                  TextCapitalization.characters,
                                              decoration: const InputDecoration(
                                                counterText: '',
                                              ),
                                              onChanged: _handleTextChange,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ClueBar(
              clue: displayedClue,
              isCompleted: _isCurrentWordCompleted(controller),
              onPrevious: () {
                controller.previousWord();
                _requestKeyboard();
              },
              onNext: () {
                controller.nextWord();
                _requestKeyboard();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  bool _isCurrentWordCompleted(CrosswordController controller) {
    final currentWord = controller.currentWord;
    if (currentWord == null) return false;

    final board = controller.board;
    for (var i = 0; i < currentWord.length; i++) {
      final row = currentWord.row + (currentWord.isDown ? i : 0);
      final col = currentWord.col + (currentWord.isAcross ? i : 0);

      if (row >= board.length || col >= board[row].length) return false;

      final cell = board[row][col];
      if (cell.entry.toUpperCase() != cell.solution.toUpperCase()) {
        return false;
      }
    }
    return true;
  }

  void _ensureClueAnimation(String clue) {
    if (_currentFullClue == clue) return;
    _currentFullClue = clue;
    _clueAnimationTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _typedClue = '';
      });
      if (clue.isEmpty) {
        return;
      }
      var index = 0;
      _clueAnimationTimer = Timer.periodic(const Duration(milliseconds: 30), (
        timer,
      ) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        if (index >= clue.length) {
          timer.cancel();
          return;
        }
        setState(() {
          _typedClue = clue.substring(0, index + 1);
        });
        index++;
      });
    });
  }

  String _formattedClue(String? rawClue) {
    final value = rawClue?.trim() ?? '';
    if (value.isEmpty) {
      return 'Clue belum tersedia untuk kata ini';
    }
    return value;
  }

  void _maybeShowCompletion(CrosswordController controller) {
    final solved = controller.isPuzzleSolved;
    if (!solved) {
      _completionSheetVisible = false;
      return;
    }
    if (_completionSheetVisible) return;
    _completionSheetVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showCompletionSheet(controller.elapsed);
    });
  }

  Future<void> _showCompletionSheet(Duration elapsed) async {
    final timeText = formatDuration(elapsed);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFFBF1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 34,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Selamat berhasil!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Semua jawaban benar dalam $timeText.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF0F172A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CrosswordCellWidget extends StatelessWidget {
  const _CrosswordCellWidget({
    required this.cell,
    required this.isSelected,
    required this.isActive,
    required this.cellSize,
    required this.onTap,
  });

  final BoardCell cell;
  final bool isSelected;
  final bool isActive;
  final double cellSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool hasEntry = cell.entry.isNotEmpty;
    final bool isCorrect = hasEntry && cell.isCorrect;
    final bool isIncorrect = hasEntry && !cell.isCorrect;

    Color backgroundColor;
    Color borderColor;

    if (cell.isBlock) {
      backgroundColor = Colors.grey[300]!;
      borderColor = Colors.grey[400]!;
    } else {
      if (isSelected) {
        backgroundColor = const Color(0xFF80B3FF);
        borderColor = const Color(0xFF4A7EFF);
      } else if (isCorrect) {
        backgroundColor = const Color(0xFFDFFFE5);
        borderColor = const Color(0xFF67C882);
      } else if (isIncorrect) {
        backgroundColor = const Color(0xFFFFE6E6);
        borderColor = const Color(0xFFE57373);
      } else if (isActive) {
        backgroundColor = const Color(0xFFE6F0FF);
        borderColor = const Color(0xFFBFD5FF);
      } else {
        backgroundColor = Colors.white;
        borderColor = Colors.grey[300]!;
      }
    }

    final textColor = isIncorrect
        ? const Color(0xFFB3261E)
        : cell.isFirstLetter
        ? Colors.black87
        : Colors.black87;

    final fontSize = (cellSize * 0.5).clamp(10.0, 18.0);

    return GestureDetector(
      onTap: cell.isBlock ? null : onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          cell.isBlock ? '' : cell.entry,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            letterSpacing: cellSize > 30 ? 1.5 : 0.5,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _ClueBar extends StatelessWidget {
  const _ClueBar({
    required this.clue,
    required this.isCompleted,
    required this.onPrevious,
    required this.onNext,
  });

  final String clue;
  final bool isCompleted;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E6F0)),
      ),
      child: Row(
        children: [
          _ClueNavButton(icon: Icons.chevron_left, onTap: onPrevious),
          const SizedBox(width: 12),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  clue,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    decorationThickness: 2.5,
                    decorationColor: const Color(0xFF16A34A),
                  ),
                ),
                if (isCompleted)
                  Positioned(
                    right: 4,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ClueNavButton(icon: Icons.chevron_right, onTap: onNext),
        ],
      ),
    );
  }
}

class _HintButton extends StatelessWidget {
  const _HintButton({
    required this.hintsRemaining,
    required this.hintsTotal,
    required this.onPressed,
  });

  final int hintsRemaining;
  final int hintsTotal;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool hasHints = hintsRemaining > 0;
    final Color background = hasHints
        ? const Color(0xFF0F172A)
        : const Color(0xFFE5E7EB);
    final Color foreground = hasHints ? Colors.white : const Color(0xFF9CA3AF);

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            '$hintsRemaining/$hintsTotal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClueNavButton extends StatelessWidget {
  const _ClueNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.zoomLevel,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final double zoomLevel;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final canZoomIn = zoomLevel < 2.0;
    final canZoomOut = zoomLevel > 0.7;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE1E6F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(
            icon: Icons.remove,
            enabled: canZoomOut,
            onPressed: canZoomOut ? onZoomOut : null,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '${(zoomLevel * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          _ZoomButton(
            icon: Icons.add,
            enabled: canZoomIn,
            onPressed: canZoomIn ? onZoomIn : null,
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.grey[200],
          borderRadius: BorderRadius.circular(999),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? const Color(0xFF0F172A) : Colors.grey[400],
        ),
      ),
    );
  }
}
