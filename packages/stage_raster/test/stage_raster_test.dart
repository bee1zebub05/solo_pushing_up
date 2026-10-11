import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:stage_raster/stage_raster.dart';

void main() {
  var now = 0;
  late RasterBudget budget;
  setUp(() {
    now = 0;
    budget = RasterBudget(
      scale: 2,
      maxScale: 3,
      budgetBytes: 3 * 100 * 100 * 4, // đủ đúng 3 ảnh 100×100 điểm ảnh
      protectMs: 100,
      clock: () => now,
    );
  });

  RasterLayer layer() => RasterLayer(
    (c) => c.drawRect(const Rect.fromLTWH(0, 0, 50, 50), Paint()),
    bounds: const Rect.fromLTWH(0, 0, 50, 50),
    budget: budget,
  );

  void paint(RasterLayer l) {
    final r = PictureRecorder();
    l.paint(Canvas(r));
    r.endRecording().dispose();
  }

  test('chụp một lần, các lần vẽ sau dùng lại ảnh', () {
    final l = layer();
    paint(l);
    paint(l);
    expect(l.renders, 1);
    expect(l.bytes, 100 * 100 * 4);
    expect(budget.bytes, l.bytes);
  });

  test('trần độ phân giải giới hạn kích thước ảnh', () {
    budget.scale = 6; // máy nằm ngang
    final l = layer();
    expect(l.pixelSize(), (150, 150)); // 50 × trần 3
  });

  test('vượt ngân sách: giải phóng lớp lâu không vẽ nhất', () {
    final a = layer(), b = layer(), c = layer(), d = layer();
    paint(a);
    now = 200;
    paint(b);
    now = 400;
    paint(c);
    now = 600;
    paint(d); // 4 ảnh > ngân sách 3 → a (cũ nhất) bị giải phóng
    expect(a.hasImage, isFalse);
    expect([b.hasImage, c.hasImage, d.hasImage], everyElement(isTrue));
    expect(budget.liveCount, 3);
    // Vẽ lại a thì chụp lại, và lần này b là cũ nhất.
    now = 800;
    paint(a);
    expect(a.renders, 2);
    expect(b.hasImage, isFalse);
  });

  test('không giải phóng lớp vừa vẽ (đang trên màn hình), ghi nhận vượt', () {
    final a = layer(), b = layer(), c = layer(), d = layer();
    for (final l in [a, b, c, d]) {
      paint(l); // cùng thời điểm: đều đang hiện
    }
    expect(budget.liveCount, 4);
    expect(budget.overBudgetEvents, greaterThan(0));
  });

  test('đổi độ phân giải > 15 % thì chụp lại', () {
    final l = layer();
    paint(l);
    budget.scale = 2.1;
    paint(l);
    expect(l.renders, 1);
    budget.scale = 3;
    paint(l);
    expect(l.renders, 2);
    expect(l.pixelSize(), (150, 150));
  });

  test('purge giải phóng hết', () {
    final a = layer(), b = layer();
    paint(a);
    paint(b);
    budget.purge();
    expect(budget.liveCount, 0);
    expect(budget.bytes, 0);
    expect(a.hasImage || b.hasImage, isFalse);
  });
}
