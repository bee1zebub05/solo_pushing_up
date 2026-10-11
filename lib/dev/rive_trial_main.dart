import 'package:flame_rive/flame_rive.dart' show RiveNative;
import 'package:flutter/material.dart';

import '../ui/rive_trial_screen.dart';

/// Chạy thẳng màn thử Rive (không qua trang chủ):
/// `flutter run -t lib/dev/rive_trial_main.dart`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RiveNative.init();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const RiveTrialScreen(),
    ),
  );
}
