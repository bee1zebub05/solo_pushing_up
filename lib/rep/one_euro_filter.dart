import 'dart:math' as math;

/// One Euro filter (Casiez et al., CHI 2012): lọc rung mạnh khi đứng yên,
/// nhưng ít trễ khi chuyển động nhanh — hợp với rep nhanh.
class OneEuroFilter {
  OneEuroFilter({
    this.minCutoff = 1.0,
    this.beta = 0.0,
    this.derivativeCutoff = 1.0,
  });

  /// Tần số cắt (Hz) khi đứng yên. Thấp hơn = mượt hơn nhưng trễ hơn.
  final double minCutoff;

  /// Tăng tần số cắt theo tốc độ. Cao hơn = ít trễ hơn khi chuyển động nhanh.
  final double beta;
  final double derivativeCutoff;

  double? _prevValue;
  double? _prevTime;
  double _prevDerivative = 0;

  double filter(double value, double timeSeconds) {
    final prevValue = _prevValue;
    final prevTime = _prevTime;
    if (prevValue == null || prevTime == null) {
      _prevValue = value;
      _prevTime = timeSeconds;
      return value;
    }
    final dt = timeSeconds - prevTime;
    if (dt <= 0) return prevValue;

    final derivative = (value - prevValue) / dt;
    _prevDerivative = _lerp(
      _prevDerivative,
      derivative,
      _alpha(derivativeCutoff, dt),
    );
    final cutoff = minCutoff + beta * _prevDerivative.abs();
    final result = _lerp(prevValue, value, _alpha(cutoff, dt));

    _prevValue = result;
    _prevTime = timeSeconds;
    return result;
  }

  void reset() {
    _prevValue = null;
    _prevTime = null;
    _prevDerivative = 0;
  }

  static double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
