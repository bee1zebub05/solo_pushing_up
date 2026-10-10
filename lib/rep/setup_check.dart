import 'dart:math' as math;

import '../pose/pose_frame.dart';

/// Các vấn đề khi đặt máy, theo thứ tự cần sửa trước.
enum SetupIssue {
  /// Không thấy người trong khung hình.
  noPerson(blocking: true),

  /// Không thấy đủ vai, khuỷu tay, cổ tay của ít nhất một bên.
  armsNotVisible(blocking: true),

  /// Tay hoặc vai sát mép ảnh, dễ ra khỏi khung khi hít đất.
  cutOffEdge(blocking: true),

  /// Người quá gần camera.
  tooClose(blocking: false),

  /// Người quá xa, khớp nhỏ và nhiễu.
  tooFar(blocking: false),

  /// Máy chưa đặt trước mặt (đang chéo/ngang): vẫn đếm được nhưng người
  /// chơi không nhìn được màn hình khi tập. Cách khuyên dùng là dựng máy
  /// trước mặt như Pushup RPG; bộ đếm dùng độ sâu vai–cổ tay ở góc này.
  notFacing(blocking: false),

  /// Ảnh tối.
  tooDark(blocking: false);

  const SetupIssue({required this.blocking});

  /// Có vấn đề này thì gần như chắc chắn đếm sai.
  final bool blocking;
}

class SetupCheckConfig {
  const SetupCheckConfig({
    this.minConfidence = 0.5,
    this.edgeMargin = 0.02,
    this.minArmScale = 0.12,
    this.maxArmScale = 0.6,
    this.frontViewRatio = 1.2,
    this.minBrightness = 45,
    this.windowFrames = 15,
    this.reportRatio = 0.6,
  });

  final double minConfidence;

  /// Khớp nằm trong phần mép này (tỉ lệ kích thước ảnh) coi là sát mép.
  final double edgeMargin;

  /// Chiều dài tay (vai→khuỷu→cổ tay) / cạnh dài của ảnh.
  final double minArmScale;
  final double maxArmScale;

  /// Bề ngang hai vai / chiều dài cánh tay trên. Đo trên 144 clip Mendeley
  /// (p10–p90): ngang 0,21–0,44, chéo 0,54–0,92, chính diện 1,5–2,0.
  final double frontViewRatio;

  /// Độ sáng trung bình 0..255.
  final double minBrightness;

  /// Chỉ báo vấn đề có mặt ở ít nhất [reportRatio] trong [windowFrames]
  /// khung gần nhất, để thông báo không nhấp nháy.
  final int windowFrames;
  final double reportRatio;
}

/// Kiểm tra cách đặt máy từ chuỗi khung hình, trước khi bắt đầu tập.
class SetupChecker {
  SetupChecker({this.config = const SetupCheckConfig()});

  final SetupCheckConfig config;
  final List<Set<SetupIssue>> _window = [];

  /// Thêm một khung hình, trả về các vấn đề ổn định (đã lọc nhấp nháy).
  Set<SetupIssue> update(PoseFrame frame) {
    _window.add(checkFrame(frame));
    if (_window.length > config.windowFrames) _window.removeAt(0);
    final threshold = (_window.length * config.reportRatio).ceil();
    return {
      for (final issue in SetupIssue.values)
        if (_window.where((s) => s.contains(issue)).length >= threshold) issue,
    };
  }

  void reset() => _window.clear();

  /// Vấn đề của riêng một khung hình.
  Set<SetupIssue> checkFrame(PoseFrame frame) {
    final issues = <SetupIssue>{};
    final brightness = frame.brightness;
    if (brightness != null && brightness < config.minBrightness) {
      issues.add(SetupIssue.tooDark);
    }

    Landmark? visible(Joint joint) {
      final l = frame[joint];
      return l != null && l.confidence >= config.minConfidence ? l : null;
    }

    final leftShoulder = visible(Joint.leftShoulder);
    final rightShoulder = visible(Joint.rightShoulder);
    if (frame.isEmpty || (leftShoulder == null && rightShoulder == null)) {
      return issues..add(SetupIssue.noPerson);
    }

    final arms = [
      for (final (s, e, w) in const [
        (Joint.leftShoulder, Joint.leftElbow, Joint.leftWrist),
        (Joint.rightShoulder, Joint.rightElbow, Joint.rightWrist),
      ])
        if ((visible(s), visible(e), visible(w)) case (
          final shoulder?,
          final elbow?,
          final wrist?,
        ))
          (shoulder: shoulder, elbow: elbow, wrist: wrist),
    ];
    if (arms.isEmpty) return issues..add(SetupIssue.armsNotVisible);

    final size = frame.imageSize;
    final marginX = size.width * config.edgeMargin;
    final marginY = size.height * config.edgeMargin;
    final keyJoints = [
      for (final arm in arms) ...[arm.shoulder, arm.elbow, arm.wrist],
    ];
    if (keyJoints.any(
      (l) =>
          l.x < marginX ||
          l.y < marginY ||
          l.x > size.width - marginX ||
          l.y > size.height - marginY,
    )) {
      issues.add(SetupIssue.cutOffEdge);
    }

    final longSide = math.max(size.width, size.height);
    final armScale =
        arms
            .map((a) => _dist(a.shoulder, a.elbow) + _dist(a.elbow, a.wrist))
            .reduce(math.max) /
        longSide;
    if (armScale > config.maxArmScale) issues.add(SetupIssue.tooClose);
    if (armScale < config.minArmScale) issues.add(SetupIssue.tooFar);

    if (leftShoulder != null && rightShoulder != null) {
      final upperArm = arms
          .map((a) => _dist(a.shoulder, a.elbow))
          .reduce(math.max);
      if (upperArm > 0 &&
          _dist(leftShoulder, rightShoulder) / upperArm <
              config.frontViewRatio) {
        issues.add(SetupIssue.notFacing);
      }
    }
    return issues;
  }

  static double _dist(Landmark a, Landmark b) =>
      math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
}
