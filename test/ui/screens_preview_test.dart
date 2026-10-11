import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/game/progress.dart';
import 'package:solo_pushing_up/ui/home_screen.dart';
import 'package:solo_pushing_up/ui/stage_select_screen.dart';

/// Ảnh chụp các màn giao diện ở cỡ iPhone (390×844 pt, @3x) với font thật
/// (Roboto của Flutter SDK) để soát bố cục và chữ. Chỉ ghi PNG khi
/// ART_PREVIEW=1; mặc định chỉ kiểm tra dựng không lỗi.
Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
  if (!dir.existsSync()) return;
  for (final (family, files) in [
    ('Roboto', ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf']),
    ('MaterialIcons', ['materialicons-regular.otf']),
  ]) {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('${dir.path}/$f');
      if (file.existsSync()) {
        loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
      }
    }
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, GlobalKey key, String name) async {
  if (Platform.environment['ART_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File('build/art_preview/screen_$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  Future<GlobalKey> pumpScreen(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.amber,
              brightness: Brightness.dark,
            ),
          ),
          home: home,
        ),
      ),
    );
    return key;
  }

  testWidgets('màn chọn màn Nemea (iPhone dọc)', (tester) async {
    final nemea = labors.firstWhere((l) => l.id == 'nemea');
    final key = await pumpScreen(
      tester,
      StageSelectScreen(
        labor: nemea,
        progress: PlayerProgress(
          completedStages: {'nemea_1_1', 'nemea_1_2', 'nemea_1_3'},
        ),
        onPlay: (_) async {},
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _shot(tester, key, 'stage_select');
  });

  testWidgets('màn chính (iPhone dọc)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final key = await pumpScreen(tester, const HomeScreen());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 500));
    await _shot(tester, key, 'home');
  });
}
