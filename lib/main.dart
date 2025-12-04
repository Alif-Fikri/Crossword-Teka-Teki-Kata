import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/crossword_repository.dart';
import 'data/storage/hive_boxes.dart';
import 'state/crossword_controller.dart';
import 'ui/game_screen.dart';
import 'ui/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBoxes.init();
  final repository = CrosswordRepository();
  runApp(CrosswordApp(repository: repository));
}

class CrosswordApp extends StatelessWidget {
  const CrosswordApp({super.key, required this.repository});

  final CrosswordRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CrosswordController(repository: repository),
      child: MaterialApp(
        title: 'Crossword',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF80B3FF)),
          useMaterial3: true,
        ),
        routes: {
          '/': (_) => const StartScreen(),
          GameScreen.routeName: (_) => const GameScreen(),
        },
        initialRoute: '/',
      ),
    );
  }
}
