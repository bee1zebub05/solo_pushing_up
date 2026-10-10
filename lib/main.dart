import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Cho xoay ngang: phòng nhỏ đôi khi chỉ đặt máy nằm ngang được
  // (review Pushup RPG chê ép xoay camera).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const SoloPushingUpApp());
}

class SoloPushingUpApp extends StatelessWidget {
  const SoloPushingUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solo Pushing Up',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
