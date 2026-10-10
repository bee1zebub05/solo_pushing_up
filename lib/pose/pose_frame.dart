import 'dart:math' as math;

// File này không import Flutter để rep engine và công cụ tool/replay.dart
// chạy được bằng `dart run` trên máy tính.

/// Các khớp cơ thể mà rep engine cần. Giữ độc lập với ML Kit để
/// rep engine chạy được trên dữ liệu test và đổi model pose sau này.
enum Joint {
  nose,
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

class Landmark {
  const Landmark(this.x, this.y, this.confidence);

  /// Toạ độ pixel trong ảnh đã xoay thẳng đứng (upright).
  final double x;
  final double y;

  /// Độ tin cậy 0..1 (ML Kit gọi là likelihood).
  final double confidence;
}

class ImageSize {
  const ImageSize(this.width, this.height);

  final double width;
  final double height;
}

/// Một khung hình tư thế: các khớp phát hiện được tại một thời điểm.
class PoseFrame {
  const PoseFrame({
    required this.timestampMs,
    required this.landmarks,
    required this.imageSize,
    this.brightness,
    this.processingMs,
  });

  final int timestampMs;
  final Map<Joint, Landmark> landmarks;

  /// Kích thước ảnh đã xoay thẳng đứng, cùng hệ toạ độ với [landmarks].
  final ImageSize imageSize;

  /// Độ sáng trung bình 0..255 của ảnh camera (không có với dữ liệu ghi sẵn).
  final double? brightness;

  /// Thời gian model pose xử lý khung này (ms), để đo hiệu năng.
  final int? processingMs;

  Landmark? operator [](Joint joint) => landmarks[joint];

  bool get isEmpty => landmarks.isEmpty;
}

/// Góc tại [b] (độ) tạo bởi đoạn b→a và b→c. 180° là thẳng hàng.
double angleDeg(Landmark a, Landmark b, Landmark c) {
  final abx = a.x - b.x;
  final aby = a.y - b.y;
  final cbx = c.x - b.x;
  final cby = c.y - b.y;
  final norm = math.sqrt((abx * abx + aby * aby) * (cbx * cbx + cby * cby));
  if (norm == 0) return 180;
  final cos = ((abx * cbx + aby * cby) / norm).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}
