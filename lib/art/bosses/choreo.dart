/// Biên đạo đòn theo khoá — bản Dart của tool/motion/choreo.py (rules/dohoa/chuyendong.md). Cùng dữ liệu (choreo_data.dart sinh từ JSON) và cùng phép nội suy
/// cubic đơn điệu Fritsch–Carlson, nên bản vector 2.5D đi đúng nhịp, đúng tư
/// thế khoá như sprite Blender. Hai bộ nội suy được test so khớp.
library;

import 'dart:math' as math;

/// Một đòn: khoá (t, {kênh: giá trị}); khoá có thể thiếu kênh.
class MoveSpec {
  const MoveSpec({
    required this.keys,
    this.events = const {},
    this.holdEnd = false,
  });

  final List<(double, Map<String, double>)> keys;

  /// Mốc đặc biệt (ví dụ `impact`: lúc vũ khí chạm đích).
  final Map<String, double> events;

  /// Đòn gục: giữ tư thế cuối, không trở về "ready".
  final bool holdEnd;
}

class ChoreoSpec {
  const ChoreoSpec({required this.ready, required this.lag, required this.moves});

  final Map<String, double> ready;
  final Map<String, double> lag;
  final Map<String, MoveSpec> moves;
}

class _Track {
  _Track(List<(double, double)> keys) {
    keys.sort((a, b) => a.$1.compareTo(b.$1));
    xs = [for (final k in keys) k.$1];
    ys = [for (final k in keys) k.$2];
    ms = _monotone(xs, ys);
  }

  late final List<double> xs, ys, ms;

  static List<double> _monotone(List<double> xs, List<double> ys) {
    final n = xs.length;
    if (n < 2) return List.filled(n, 0);
    final d = [
      for (var i = 0; i < n - 1; i++)
        (ys[i + 1] - ys[i]) / math.max(1e-9, xs[i + 1] - xs[i]),
    ];
    final m = [
      d[0],
      for (var i = 1; i < n - 1; i++)
        d[i - 1] * d[i] > 0 ? (d[i - 1] + d[i]) / 2 : 0.0,
      d[n - 2],
    ];
    for (var i = 0; i < n - 1; i++) {
      if (d[i] == 0) {
        m[i] = 0;
        m[i + 1] = 0;
        continue;
      }
      final a = m[i] / d[i], b = m[i + 1] / d[i];
      final s = a * a + b * b;
      if (s > 9) {
        final k = 3 / math.sqrt(s);
        m[i] = k * a * d[i];
        m[i + 1] = k * b * d[i];
      }
    }
    return m;
  }

  double at(double t) {
    if (t <= xs.first) return ys.first;
    if (t >= xs.last) return ys.last;
    var i = 0;
    while (xs[i + 1] <= t) {
      i++;
    }
    final h = xs[i + 1] - xs[i];
    final u = (t - xs[i]) / h;
    final h00 = (1 + 2 * u) * (1 - u) * (1 - u);
    final h10 = u * (1 - u) * (1 - u);
    final h01 = u * u * (3 - 2 * u);
    final h11 = u * u * (u - 1);
    return h00 * ys[i] + h10 * h * ms[i] + h01 * ys[i + 1] + h11 * h * ms[i + 1];
  }
}

/// Mẫu tư thế của một đòn tại tiến độ t → {kênh: giá trị}.
class Move {
  Move(ChoreoSpec spec, MoveSpec move)
    : lag = spec.lag,
      events = move.events {
    final chans = <String, List<(double, double)>>{
      for (final c in spec.ready.keys) c: [],
    };
    for (final (t, v) in move.keys) {
      v.forEach((c, x) => chans.putIfAbsent(c, () => []).add((t, x)));
    }
    chans.forEach((c, ks) {
      final r = spec.ready[c] ?? 0;
      final all = [(0.0, r), ...ks];
      if (!move.holdEnd && !all.any((k) => k.$1 >= 1)) all.add((1.0, r));
      _tracks[c] = _Track(all);
    });
  }

  final Map<String, double> lag;
  final Map<String, double> events;
  final _tracks = <String, _Track>{};

  Map<String, double> at(double t) => {
    for (final e in _tracks.entries)
      e.key: e.value.at(math.max(0, t - (lag[e.key] ?? 0))),
  };
}

/// Biên đạo một boss: các đòn đã dựng sẵn track.
class Choreo {
  Choreo(this.spec)
    : moves = {
        for (final e in spec.moves.entries) e.key: Move(spec, e.value),
      };

  final ChoreoSpec spec;
  final Map<String, Move> moves;

  Map<String, double> get ready => spec.ready;
}
