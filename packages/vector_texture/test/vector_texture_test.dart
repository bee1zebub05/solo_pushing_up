import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_texture/vector_texture.dart';

void main() {
  test('lockLine: đủ điểm, dài gần đúng, ngọn bị kéo theo drift', () {
    final line = lockLine(-math.pi / 2, 10, 30, drift: const Offset(0.4, 0));
    expect(line, hasLength(6));
    expect(line.first.dy, closeTo(-10, 1e-9));
    var len = 0.0;
    for (var i = 1; i < line.length; i++) {
      len += (line[i] - line[i - 1]).distance;
    }
    expect(len, closeTo(30, 0.5));
    // Mọc thẳng lên, bị kéo sang +x: ngọn nằm bên phải gốc.
    expect(line.last.dx, greaterThan(line.first.dx + 5));
  });

  test('buildLocks: cùng seed thì cùng hình, mỗi lọn một đường giữa', () {
    LockSet make() => buildLocks(
      center: const Offset(50, 50),
      rnd: math.Random(3),
      r0: 10,
      length: 20,
      width: 6,
      count: 12,
      from: -2,
      to: 2,
    );
    final a = make(), b = make();
    expect(a.lines, hasLength(12));
    expect(a.mass.getBounds(), b.mass.getBounds());
    expect(a.creases.getBounds().isEmpty, isFalse);
    // Khối nằm quanh tâm, không văng xa quá độ dài lọn.
    final r = a.mass.getBounds();
    expect(r.left, greaterThan(50 - 10 - 20 * 1.3 - 6));
    expect(r.right, lessThan(50 + 10 + 20 * 1.3 + 6));
  });

  test('curlRows phủ đúng vùng', () {
    final c = curlRows(
      const Rect.fromLTWH(0, 0, 40, 20),
      radius: 2.5,
      rnd: math.Random(1),
    );
    final r = c.dark.getBounds();
    expect(r.left, lessThan(3));
    expect(r.right, greaterThan(37));
    expect(r.bottom, greaterThan(17));
    expect(c.lit.getBounds().isEmpty, isFalse);
  });

  test('buildScaleBody: vảy và bụng nằm trong thân', () {
    final s = buildScaleBody(const [
      Offset(0, 0),
      Offset(40, 10),
      Offset(80, 0),
      Offset(120, 10),
    ], 20);
    final body = s.body.getBounds().inflate(2);
    for (final p in [s.scaleDark, s.scaleLit, s.spine, s.belly, s.plates]) {
      final r = p.getBounds();
      expect(r.isEmpty, isFalse);
      expect(body.contains(r.topLeft) && body.contains(r.bottomRight), isTrue);
    }
  });

  test('buildScaleBody không bụng thì không có dải bụng', () {
    final s = buildScaleBody(
      const [Offset(0, 0), Offset(60, 0)],
      12,
      belly: false,
    );
    expect(s.belly.getBounds().isEmpty, isTrue);
    expect(s.plates.getBounds().isEmpty, isTrue);
  });

  test('featherRows: ngọn theo hướng tipDir', () {
    final f = featherRows(const Rect.fromLTWH(0, 0, 30, 20), size: 5);
    final r = f.dark.getBounds();
    // Ngọn chĩa xuống: vượt quá đáy vùng gần một chiều dài lông.
    expect(r.bottom, greaterThan(20));
    expect(r.top, greaterThan(-1));
  });
}
