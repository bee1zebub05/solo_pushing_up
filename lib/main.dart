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
        // App nền tối: chữ thanh trạng thái (giờ, pin) luôn sáng, kể cả khi
        // iPhone đang ở chế độ sáng.
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      // Màn không có AppBar (trận, đếm rep, mở đầu) cũng dùng chữ sáng.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
