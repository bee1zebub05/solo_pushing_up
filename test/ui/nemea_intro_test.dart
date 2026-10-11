import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/ui/nemea_intro_screen.dart';

void main() {
  testWidgets('cảnh mở đầu: chạm qua hết lời Hercules thì vào trận', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var done = false;
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: NemeaIntroScreen(
            look: const HeroLook(),
            onDone: () => done = true,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 3));

    if (Platform.environment['ART_PREVIEW'] == '1') {
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File('build/art_preview/intro_screen.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    // Mỗi câu: chạm để hiện hết, chạm lần nữa để sang câu sau.
    for (var i = 0; i < nemeaIntroLines.length * 2 && !done; i++) {
      await tester.tapAt(const Offset(200, 300));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, isTrue);
  });
}
