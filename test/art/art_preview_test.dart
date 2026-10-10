import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/art/hero_pose.dart';
import 'package:solo_pushing_up/art/lion_art.dart';
import 'package:solo_pushing_up/art/nemea_scene.dart';
import 'package:solo_pushing_up/art/nemea_stage.dart';

/// Vẽ thử các khung hình nhân vật. Mặc định chỉ kiểm tra vẽ không lỗi;
/// đặt biến môi trường ART_PREVIEW=1 để ghi PNG vào build/art_preview/.
Future<void> render(
  WidgetTester tester,
  String name,
  void Function(ui.Canvas) draw, {
  double scale = 2,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(scale);
  draw(canvas);
  final picture = recorder.endRecording();
  if (Platform.environment['ART_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final image = await picture.toImage(
      (stageSize.width * scale).round(),
      (stageSize.height * scale).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/art_preview/$name.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void scene(
  ui.Canvas canvas,
  HeroPose hero, {
  bool cloak = false,
  LionState lion = const LionState(),
}) {
  paintNemeaScene(canvas);
  canvas.save();
  canvas.translate(lionX, stageGroundY);
  canvas.scale(lionScale);
  paintLion(canvas, lion);
  canvas.restore();
  paintHero(canvas, hero, cloak: cloak);
}

void main() {
  testWidgets('chống đẩy: tay thẳng, giữa chừng, xuống sâu', (tester) async {
    for (final angle in [180.0, 120.0, 70.0]) {
      await render(
        tester,
        'plank_${angle.round()}',
        (c) => scene(c, HeroPose.plank(angle)),
      );
    }
  });

  testWidgets('chống gối và khoác áo da sư tử', (tester) async {
    await render(
      tester,
      'knee_90',
      (c) => scene(c, HeroPose.plank(90, onKnees: true)),
    );
    await render(
      tester,
      'cloak_plank',
      (c) => scene(c, HeroPose.plank(100), cloak: true),
    );
  });

  testWidgets('đứng chờ, ăn mừng, sư tử gầm / trúng đòn / gục', (tester) async {
    await render(
      tester,
      'standing',
      (c) => scene(c, HeroPose.standing(), lion: const LionState(mouth: 1)),
    );
    await render(
      tester,
      'victory',
      (c) => scene(
        c,
        HeroPose.victory(),
        cloak: true,
        lion: const LionState(defeat: 1),
      ),
    );
    await render(
      tester,
      'lion_hurt',
      (c) => scene(
        c,
        HeroPose.plank(170),
        lion: const LionState(hurt: 0.8, glint: 0.4),
      ),
    );
  });

  testWidgets('đủ kiểu nhân vật: nam/nữ, gầy/béo, tóc, da, cao/thấp', (
    tester,
  ) async {
    const looks = [
      HeroLook(),
      HeroLook(fat: 0.9, skin: Color(0xFFC68A5E), hairStyle: HairStyle.buzz),
      HeroLook(
        sex: HeroSex.female,
        hairStyle: HairStyle.ponytail,
        skin: Color(0xFFF6D3B8),
        height: 0.92,
      ),
      HeroLook(
        sex: HeroSex.female,
        fat: 0.85,
        hairStyle: HairStyle.bun,
        hair: Color(0xFFB0472A),
      ),
      HeroLook(
        sex: HeroSex.female,
        hairStyle: HairStyle.long,
        skin: Color(0xFF6B4329),
        height: 1.08,
      ),
      HeroLook(fat: 0.4, hair: Color(0xFF9A9A9A), height: 1.1),
    ];
    await render(tester, 'lineup', (c) {
      c.drawRect(
        const Rect.fromLTWH(0, 0, 400, 260),
        Paint()..color = const Color(0xFFEDE3CF),
      );
      for (var i = 0; i < looks.length; i++) {
        paintHero(c, HeroPose.standing(x: 30.0 + i * 65), look: looks[i]);
      }
    });
    await render(tester, 'plank_looks', (c) {
      paintNemeaScene(c);
      paintHero(c, HeroPose.plank(110), look: looks[3]);
      c.save();
      c.translate(190, -90);
      paintHero(c, HeroPose.plank(150), look: looks[4]);
      c.restore();
    });
  });

  test('IK chống đẩy giữ đúng độ dài tay', () {
    for (final angle in [180.0, 140.0, 100.0, 60.0]) {
      final p = HeroPose.plank(angle);
      final upper = (p[HeroJoint.elbow] - p[HeroJoint.shoulder]).distance;
      final fore = (p[HeroJoint.wrist] - p[HeroJoint.elbow]).distance;
      expect(upper, closeTo(HeroBody.upperArm, 0.5), reason: 'góc $angle');
      expect(fore, closeTo(HeroBody.forearm, 0.5), reason: 'góc $angle');
    }
  });

  test('xuống sâu thì vai thấp hơn', () {
    final top = HeroPose.plank(175)[HeroJoint.shoulder].dy;
    final bottom = HeroPose.plank(70)[HeroJoint.shoulder].dy;
    expect(bottom, greaterThan(top + 20));
  });
}
