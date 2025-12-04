import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/crossword_controller.dart';
import 'game_screen.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _checkingSession = true;
  bool _hasSavedSession = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final controller = context.read<CrosswordController>();
    final lastName = controller.repository.loadLastPlayerName();
    final savedSession = await controller.repository.loadActiveSession();
    if (!mounted) return;
    if (lastName != null) {
      _nameController.text = lastName;
    }
    setState(() {
      _hasSavedSession = savedSession != null;
      _checkingSession = false;
    });
  }

  Future<void> _startNewGame() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack(
        ScaffoldMessenger.of(context),
        'Masukkan nama terlebih dahulu.',
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = context.read<CrosswordController>();
    await controller.startNewSession(name);
    if (!mounted) return;
    if (controller.error != null) {
      _showSnack(messenger, controller.error!);
      return;
    }
    setState(() {
      _hasSavedSession = true;
    });
    _navigateToGame(navigator);
  }

  Future<void> _continueGame() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = context.read<CrosswordController>();
    final ok = await controller.loadExistingSession();
    if (!mounted) return;
    if (!ok || controller.error != null) {
      _showSnack(messenger, controller.error ?? 'Tidak ada sesi tersimpan.');
      return;
    }
    _navigateToGame(navigator);
  }

  void _navigateToGame(NavigatorState navigator) {
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  Future<void> _resetProgress() async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<CrosswordController>();
    final shouldReset =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset permainan?'),
            content: const Text(
              'Semua jawaban tersimpan akan dihapus. Kamu bisa memulai ulang dengan puzzle terbaru.',
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
    setState(() {
      _hasSavedSession = false;
    });
    _showSnack(messenger, 'Permainan berhasil direset.');
  }

  void _showSnack(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CrosswordController>();
    final Widget content = _checkingSession
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 64,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StartHeader(),
                      const SizedBox(height: 32),
                      _StartCard(
                        controller: controller,
                        nameController: _nameController,
                        hasSavedSession: _hasSavedSession,
                        onStart: controller.isLoading ? null : _startNewGame,
                        onContinue: controller.isLoading ? null : _continueGame,
                        onReset: controller.isLoading ? null : _resetProgress,
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Kemajuanmu tersimpan otomatis di perangkat ini.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: content,
        ),
      ),
    );
  }
}

class _StartHeader extends StatelessWidget {
  const _StartHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF5667FF),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Crossword Daily',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF5667FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Tantangan kata teka - teki',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Isi teka-teki silang favoritmu dengan tampilan bersih tanpa distraksi.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 1,
            children: const [
              _PillChip(label: '20x20 grid'),
              _PillChip(label: 'Auto-save'),
              _PillChip(label: 'Hint terbatas'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.controller,
    required this.nameController,
    required this.hasSavedSession,
    required this.onStart,
    required this.onContinue,
    required this.onReset,
  });

  final CrosswordController controller;
  final TextEditingController nameController;
  final bool hasSavedSession;
  final VoidCallback? onStart;
  final VoidCallback? onContinue;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Masukkan nama untuk memulai',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: nameController,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Nama pemain',
              filled: true,
              fillColor: const Color(0xFFF7F8FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF111827),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: controller.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Text(
                    'Mulai permainan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
          if (hasSavedSession) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onContinue,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: const Color(0xFF111827),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('Lanjutkan permainan'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: const Color(0xFFB42318),
              ),
              child: const Text('Reset permainan'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  const _PillChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5667FF),
        ),
      ),
    );
  }
}
