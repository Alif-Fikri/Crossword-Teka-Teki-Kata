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
  String _typedClue = '';
  String? _currentFullClue;
  Timer? _clueAnimationTimer;
  bool _completionSheetVisible = false;

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
                            fontSize: 22,
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
                  const SizedBox(width: 12),
                  _HintButton(
                    hintsRemaining: hintsRemaining,
                    hintsTotal: hintsTotal,
                    onPressed: hintsRemaining > 0
                        ? () => _handleHintPressed(controller)
                        : null,
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
                            final cellSize = (constraints.maxWidth) / cols;
                            final gridSize = cellSize * rows;
                            final wordCells = controller.activeWordCells;
                            return SizedBox(
                              width: gridSize,
                              height: gridSize,
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
                            );
                          },
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ClueBar(
              clue: displayedClue,
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
    required this.onTap,
  });

  final BoardCell cell;
  final bool isSelected;
  final bool isActive;
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

    final textColor = isIncorrect ? const Color(0xFFB3261E) : Colors.black87;

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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
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
    required this.onPrevious,
    required this.onNext,
  });

  final String clue;
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
            child: Text(
              clue,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
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
