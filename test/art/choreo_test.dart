import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/bosses/choreo.dart';
import 'package:solo_pushing_up/art/bosses/choreo_data.dart';

/// Bộ nội suy biên đạo Dart phải khớp bản Python (tool/blender/choreo.py) —
/// nếu lệch, bản vector 2.5D đi khác nhịp sprite Blender.
void main() {
  test('nội suy Dart khớp Python ở các giá trị mẫu', () {
    expect(choreoChecks, isNotEmpty);
    final choreos = {
      for (final e in choreoData.entries) e.key: Choreo(e.value),
    };
    for (final (boss, move, t, chan, want) in choreoChecks) {
      final got = choreos[boss]!.moves[move]!.at(t)[chan]!;
      expect(got, closeTo(want, 1e-6), reason: '$boss $move t=$t $chan');
    }
  });

  test('đòn trở về tư thế chờ ở cuối, đòn gục thì giữ', () {
    for (final e in choreoData.entries) {
      final c = Choreo(e.value);
      for (final m in c.moves.entries) {
        if (e.value.moves[m.key]!.holdEnd) continue;
        final end = m.value.at(1.5);
        e.value.ready.forEach((k, v) {
          // Kênh góc (độ) chỉ cần cùng hướng: chuỳ thu vòng dưới về vai kết thúc ở
          // −212° ≡ 148° (rules/dohoa.md mục 16).
          final d = _angles.contains(k) ? ((end[k]! - v) % 360 + 540) % 360 - 180 : end[k]! - v;
          expect(d, closeTo(0, 1e-9), reason: '${e.key} ${m.key} $k');
        });
      }
    }
  });
}

const _angles = {'club', 'fan', 'hand', 'sweep'};
