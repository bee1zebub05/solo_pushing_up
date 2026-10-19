import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/sprite_atlas.dart';

/// Khung sprite không chia đều (tool/motion/sprite_plan.py): tiến độ → vị trí khung.
void main() {
  const ph = [0.0, 0.2, 0.5, 0.55, 0.6, 1.0];

  test('đúng tiến độ của một khung → đúng chỉ số khung đó', () {
    for (var i = 0; i < ph.length; i++) {
      expect(SpriteAtlas.positionOf(ph, ph[i]), closeTo(i.toDouble(), 1e-9));
    }
  });

  test('giữa hai khung → nội suy theo tiến độ, không theo chỉ số', () {
    expect(SpriteAtlas.positionOf(ph, 0.35), closeTo(1.5, 1e-9));
    expect(SpriteAtlas.positionOf(ph, 0.575), closeTo(3.5, 1e-9));
    // Chia đều thì 0,575 rơi vào khung 2,875 — lệch gần nửa khung ở pha ra đòn.
    expect(0.575 * (ph.length - 1), isNot(closeTo(3.5, 0.3)));
  });

  test('ngoài 0–1 kẹp về hai đầu', () {
    expect(SpriteAtlas.positionOf(ph, -0.2), 0);
    expect(SpriteAtlas.positionOf(ph, 1.3), ph.length - 1);
  });
}
