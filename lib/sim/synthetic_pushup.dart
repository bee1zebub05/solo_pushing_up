import 'dart:math' as math;
import 'dart:ui';

import '../pose/pose_frame.dart';

/// Sinh khung hình push-up nhìn ngang (side view) từ góc khuỷu tay, dùng cho
/// unit test và chế độ Giả lập trong app. Toạ độ pixel, trục y hướng xuống.
const _floorY = 800.0;
const _wristX = 1100.0;

// Tỉ lệ cơ thể thật, nhìn ngang: thân ≈ 1,7, đùi ≈ 1,5, cẳng chân ≈ 1,4 lần
// cánh tay trên (bộ đếm dùng tỉ lệ này để nhận ra chân/thân bị co ngắn).
const _armSegment = 200.0;
const _torso = 340.0;
const _thigh = 300.0;
const _shin = 280.0;
const frameStepMs = 33;

/// Khung ngang đủ chứa cả người nằm ngang (side view).
const syntheticImageSize = ImageSize(1400, 1000);

enum SyntheticPosture { standard, knee }

class SyntheticBody {
  const SyntheticBody({
    this.posture = SyntheticPosture.standard,
    this.hipSag = 0,
    this.confidence = 0.9,
    this.overrides = const {},
  });

  final SyntheticPosture posture;

  /// Hông võng xuống bao nhiêu pixel (thân không thẳng).
  final double hipSag;
  final double confidence;

  /// Độ tin cậy riêng cho từng khớp, ví dụ để giả lập khớp ra khỏi khung hình.
  final Map<Joint, double> overrides;
}

PoseFrame syntheticFrame(
  double elbowAngle,
  int timestampMs, {
  SyntheticBody body = const SyntheticBody(),
}) {
  final halfAngle = elbowAngle * math.pi / 360;
  final shoulderToWrist = 2 * _armSegment * math.sin(halfAngle);
  final wrist = Offset(_wristX, _floorY);
  final shoulder = Offset(_wristX, _floorY - shoulderToWrist);
  final elbow = Offset(
    _wristX + _armSegment * math.cos(halfAngle),
    _floorY - shoulderToWrist / 2,
  );

  final Offset hip;
  final Offset knee;
  final Offset ankle;
  switch (body.posture) {
    case SyntheticPosture.standard:
      // Hông võng thì gập ở hông, chân vẫn thẳng: gối võng theo tỉ lệ
      // để hông–gối–mắt cá vẫn thẳng hàng.
      const length = _torso + _thigh + _shin;
      const hipAt = _torso / length;
      const kneeAt = (_torso + _thigh) / length;
      ankle = Offset(
        shoulder.dx -
            math.sqrt(length * length - math.pow(_floorY - shoulder.dy, 2)),
        _floorY,
      );
      hip = Offset.lerp(shoulder, ankle, hipAt)! + Offset(0, body.hipSag);
      knee =
          Offset.lerp(shoulder, ankle, kneeAt)! +
          Offset(0, body.hipSag * (1 - kneeAt) / (1 - hipAt));
    case SyntheticPosture.knee:
      const length = _torso + _thigh;
      knee = Offset(
        shoulder.dx -
            math.sqrt(length * length - math.pow(_floorY - shoulder.dy, 2)),
        _floorY,
      );
      hip =
          Offset.lerp(shoulder, knee, _torso / length)! +
          Offset(0, body.hipSag);
      // Cẳng chân chếch lên phía sau.
      ankle = knee + Offset.fromDirection(math.pi + 1.0, _shin);
  }

  final points = <Joint, Offset>{
    Joint.nose: shoulder + const Offset(60, -30),
    Joint.leftShoulder: shoulder,
    Joint.rightShoulder: shoulder,
    Joint.leftElbow: elbow,
    Joint.rightElbow: elbow,
    Joint.leftWrist: wrist,
    Joint.rightWrist: wrist,
    Joint.leftHip: hip,
    Joint.rightHip: hip,
    Joint.leftKnee: knee,
    Joint.rightKnee: knee,
    Joint.leftAnkle: ankle,
    Joint.rightAnkle: ankle,
  };

  return PoseFrame(
    timestampMs: timestampMs,
    imageSize: syntheticImageSize,
    landmarks: {
      for (final MapEntry(key: joint, value: p) in points.entries)
        joint: Landmark(p.dx, p.dy, body.overrides[joint] ?? body.confidence),
    },
  );
}

/// Khung hình không thấy người (ví dụ người ra khỏi khung).
PoseFrame emptyFrame(int timestampMs) => PoseFrame(
  timestampMs: timestampMs,
  imageSize: syntheticImageSize,
  landmarks: const {},
);

/// Chuỗi góc khuỷu tay theo thời gian, ghép từ các đoạn giữ và rep.
class AngleTrack {
  final List<double> angles = [];

  int get durationMs => angles.length * frameStepMs;

  void hold(double angle, int ms) {
    for (var i = 0; i < ms ~/ frameStepMs; i++) {
      angles.add(angle);
    }
  }

  /// Một rep: xuống từ [top] tới [bottom] trong [descentMs], rồi lên trong [ascentMs].
  void rep({
    double top = 170,
    double bottom = 80,
    int descentMs = 750,
    int ascentMs = 750,
  }) {
    _ease(top, bottom, descentMs);
    _ease(bottom, top, ascentMs);
  }

  void reps(
    int n, {
    double top = 170,
    double bottom = 80,
    int descentMs = 750,
    int ascentMs = 750,
  }) {
    for (var i = 0; i < n; i++) {
      rep(top: top, bottom: bottom, descentMs: descentMs, ascentMs: ascentMs);
    }
  }

  /// Chuyển mượt từ góc hiện tại tới [angle] trong [ms].
  void moveTo(double angle, int ms) {
    _ease(angles.isEmpty ? angle : angles.last, angle, ms);
  }

  /// Cộng nhiễu ngẫu nhiên ±[amplitude] độ (seed cố định để test ổn định).
  void addNoise(double amplitude, {int seed = 42}) {
    final random = math.Random(seed);
    for (var i = 0; i < angles.length; i++) {
      angles[i] += (random.nextDouble() * 2 - 1) * amplitude;
    }
  }

  void _ease(double from, double to, int ms) {
    final steps = math.max(1, ms ~/ frameStepMs);
    for (var i = 1; i <= steps; i++) {
      final t = (1 - math.cos(math.pi * i / steps)) / 2;
      angles.add(from + (to - from) * t);
    }
  }

  List<PoseFrame> frames({
    SyntheticBody body = const SyntheticBody(),
    int startMs = 0,
  }) => [
    for (var i = 0; i < angles.length; i++)
      syntheticFrame(angles[i], startMs + i * frameStepMs, body: body),
  ];
}

/// Khung ảnh dọc như camera điện thoại dựng trước mặt người tập.
const syntheticFrontImageSize = ImageSize(1000, 1400);

/// Đổi một khung nhìn ngang ([syntheticFrame]) thành khung nhìn từ máy đặt
/// trước mặt (cách khuyên dùng, người chơi xem được màn hình): hai vai
/// rộng, khuỷu bè ra khi hạ người, vai hạ gần cổ tay. Độ sâu chọn sao cho bộ
/// đếm quy ra đúng góc khuỷu tay của khung gốc.
PoseFrame toFrontView(PoseFrame side) {
  final shoulder = side[Joint.leftShoulder];
  final elbow = side[Joint.leftElbow];
  final wrist = side[Joint.leftWrist];
  if (shoulder == null || elbow == null || wrist == null) {
    return PoseFrame(
      timestampMs: side.timestampMs,
      imageSize: syntheticFrontImageSize,
      landmarks: const {},
    );
  }
  final angle = angleDeg(shoulder, elbow, wrist);
  // Ngược với cách bộ đếm quy độ sâu ra góc (gain 200, tay thẳng = 1,3).
  const top = 1.3;
  final depth = top * (1 - (180 - angle) / 200);
  const cx = 500.0;
  const wristY = 1150.0;
  const halfShoulder = 150.0;
  final shoulderY = wristY - depth * 300;
  final flare = 165 + (top - depth) * 140;
  final armConfidence = math.min(shoulder.confidence, wrist.confidence);
  Landmark at(double x, double y, [double? c]) =>
      Landmark(x, y, c ?? armConfidence);
  return PoseFrame(
    timestampMs: side.timestampMs,
    imageSize: syntheticFrontImageSize,
    landmarks: {
      Joint.nose: at(cx, shoulderY - 45),
      Joint.leftShoulder: at(cx + halfShoulder, shoulderY),
      Joint.rightShoulder: at(cx - halfShoulder, shoulderY),
      Joint.leftElbow: at(cx + flare, (shoulderY + wristY) / 2),
      Joint.rightElbow: at(cx - flare, (shoulderY + wristY) / 2),
      Joint.leftWrist: at(cx + 175, wristY),
      Joint.rightWrist: at(cx - 175, wristY),
      // Hông ở xa camera nên nằm cao hơn vai trên ảnh.
      Joint.leftHip: at(cx + 95, shoulderY - 190),
      Joint.rightHip: at(cx - 95, shoulderY - 190),
    },
  );
}
