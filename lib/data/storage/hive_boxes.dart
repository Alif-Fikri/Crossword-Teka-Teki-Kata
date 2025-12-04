import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const settings = 'settings';
  static const session = 'session';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([Hive.openBox(settings), Hive.openBox(session)]);
  }

  static Box<dynamic> get settingsBox => Hive.box(settings);
  static Box<dynamic> get sessionBox => Hive.box(session);
}
