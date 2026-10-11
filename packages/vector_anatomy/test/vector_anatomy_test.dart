import 'dart:ui' show Path;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_anatomy/vector_anatomy.dart';

void main() {
  group('LimbFrame', () {
    test('phía trước theo hướng nhân vật nhìn', () {
      final right = LimbFrame(Offset.zero, const Offset(0, 10));
      expect(right.anterior.dx, greaterThan(0.9));
      final left = LimbFrame(
        Offset.zero,
        const Offset(0, 10),
        facing: const Offset(-1, 0),
      );
      expect(left.anterior.dx, lessThan(-0.9));
    });

    test('chi nằm ngang: phía trước là phía trên', () {
      final f = LimbFrame(Offset.zero, const Offset(10, 0));
      expect(f.anterior.dy, lessThan(-0.9));
    });

    test('at(t, s) đi dọc và ngang chi', () {
      final f = LimbFrame(Offset.zero, const Offset(0, 10));
      expect(f.at(0.5, 0), const Offset(0, 5));
      expect(f.at(1, 2).dy, closeTo(10, 1e-9));
    });
  });

  group('MuscleProfile', () {
    test('nội suy bề rộng', () {
      const side = [(0.0, 2.0), (1.0, 4.0)];
      expect(MuscleProfile.widthAt(side, 0.5), 3.0);
      expect(MuscleProfile.widthAt(side, -1), 2.0);
      expect(MuscleProfile.widthAt(side, 2), 4.0);
    });

    test('preset: đỉnh phồng hai mặt lệch độ cao (không đối xứng gương)', () {
      for (final p in [
        HumanAnatomy.upperArm,
        HumanAnatomy.forearm,
        HumanAnatomy.thigh,
        HumanAnatomy.shin,
        FelineAnatomy.hindUpper,
      ]) {
        double peakT(List<ContourStop> s) =>
            s.reduce((a, b) => a.$2 >= b.$2 ? a : b).$1;
        expect(peakT(p.anterior), isNot(peakT(p.posterior)));
      }
    });
  });

  test('buildLimb: đường bao kín bao quanh trục, có rãnh', () {
    final shape = buildLimb(
      Offset.zero,
      const Offset(0, 30),
      HumanAnatomy.upperArm,
    );
    final bounds = shape.outline.getBounds();
    expect(bounds.contains(const Offset(0, 15)), isTrue);
    expect(bounds.width, greaterThan(12));
    expect(shape.grooves, hasLength(2));
    // Viền phình to hơn thân.
    final grown = buildLimb(
      Offset.zero,
      const Offset(0, 30),
      HumanAnatomy.upperArm,
      grow: 2,
    );
    expect(grown.outline.getBounds().width, greaterThan(bounds.width + 3));
    expect(grown.grooves, isEmpty);
  });

  test('taperedStroke: mảnh ở đầu, dày ở giữa', () {
    final p = taperedStroke(const [
      Offset(0, 0),
      Offset(50, 0),
      Offset(100, 0),
    ], 6);
    expect(p.contains(const Offset(45, 0)), isTrue);
    expect(p.contains(const Offset(45, 2.6)), isTrue);
    expect(p.contains(const Offset(99.5, 2)), isFalse);
  });

  test('smoothPath đi qua các điểm', () {
    final p = smoothPath(const [Offset(0, 0), Offset(10, 10), Offset(20, 0)]);
    expect(p.getBounds().top, lessThanOrEqualTo(0.01));
    expect(p.getBounds().bottom, greaterThanOrEqualTo(9.9));
  });

  test('hai đoạn có phía trước ngược nhau vẫn gộp liền ở khớp (không lỗ)', () {
    // Cánh tay trên dọc, cẳng tay nằm ngang về phía sau lưng: phía trước của
    // hai đoạn nằm hai bên khác nhau so với hướng đi.
    final upper = buildLimb(
      Offset.zero,
      const Offset(0, 30),
      HumanAnatomy.upperArm,
    );
    final fore = buildLimb(
      const Offset(0, 30),
      const Offset(-28, 30),
      HumanAnatomy.forearm,
    );
    final body = Path()
      ..addPath(upper.outline, Offset.zero)
      ..addPath(fore.outline, Offset.zero);
    expect(body.contains(const Offset(0, 30)), isTrue);
    expect(body.contains(const Offset(-1, 29)), isTrue);
  });
}
