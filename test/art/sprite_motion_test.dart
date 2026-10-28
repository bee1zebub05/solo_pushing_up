import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/sprite_atlas.dart';
import 'package:solo_pushing_up/art/sprite_motion.dart';

void main() {
  test('đầu và cuối đòn hoà liền với dáng đứng chờ', () {
    expect(SpriteMotion.idleBlend(0), 1);
    expect(SpriteMotion.idleBlend(1), 1);
    expect(SpriteMotion.idleBlend(0.5), 0);
    expect(SpriteMotion.idleBlend(SpriteMotion.fade), 0);
    expect(SpriteMotion.idleBlend(1 - SpriteMotion.fade), 0);
    // Giảm đều, không nhảy bậc.
    var last = 1.0;
    for (var k = 1; k <= 20; k++) {
      final w = SpriteMotion.idleBlend(k / 200);
      expect(w, lessThanOrEqualTo(last));
      expect(last - w, lessThan(0.2));
      last = w;
    }
  });

  test('vùng cú đánh không hoà khung', () {
    expect(SpriteMotion.inStrike(0.3), isFalse);
    expect(SpriteMotion.inStrike(0.55), isTrue);
    expect(SpriteMotion.inStrike(0.8), isFalse);
  });

  test('tiến độ khung theo phases dồn dày', () {
    const phases = [0.0, 0.4, 0.5, 0.6, 1.0];
    expect(SpriteAtlas.positionOf(phases, 0), 0);
    expect(SpriteAtlas.positionOf(phases, 0.2), closeTo(0.5, 1e-9));
    expect(SpriteAtlas.positionOf(phases, 0.55), closeTo(2.5, 1e-9));
    expect(SpriteAtlas.positionOf(phases, 1), 4);
  });
}
