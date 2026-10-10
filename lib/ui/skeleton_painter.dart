import 'package:flutter/material.dart';

import '../pose/pose_frame.dart';

const _bones = [
  (Joint.leftShoulder, Joint.rightShoulder),
  (Joint.leftShoulder, Joint.leftElbow),
  (Joint.leftElbow, Joint.leftWrist),
  (Joint.rightShoulder, Joint.rightElbow),
  (Joint.rightElbow, Joint.rightWrist),
  (Joint.leftShoulder, Joint.leftHip),
  (Joint.rightShoulder, Joint.rightHip),
  (Joint.leftHip, Joint.rightHip),
  (Joint.leftHip, Joint.leftKnee),
  (Joint.leftKnee, Joint.leftAnkle),
  (Joint.rightHip, Joint.rightKnee),
  (Joint.rightKnee, Joint.rightAnkle),
];

/// Vẽ khung xương lên trên camera preview. Khớp mờ = độ tin cậy thấp.
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({
    required this.frame,
    required this.mirror,
    this.minConfidence = 0.5,
  });

  final PoseFrame? frame;

  /// Camera trước hiển thị kiểu gương, toạ độ ML Kit thì không.
  final bool mirror;
  final double minConfidence;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = this.frame;
    if (frame == null || frame.isEmpty) return;
    // ML Kit có thể đoán khớp nằm ngoài ảnh; không vẽ tràn ra ngoài preview.
    canvas.clipRect(Offset.zero & size);

    final scaleX = size.width / frame.imageSize.width;
    final scaleY = size.height / frame.imageSize.height;
    Offset toCanvas(Landmark l) {
      final x = l.x * scaleX;
      return Offset(mirror ? size.width - x : x, l.y * scaleY);
    }

    final bonePaint = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in _bones) {
      final la = frame[a];
      final lb = frame[b];
      if (la == null || lb == null) continue;
      final visible =
          la.confidence >= minConfidence && lb.confidence >= minConfidence;
      bonePaint.color = visible
          ? Colors.lightGreenAccent
          : Colors.white.withValues(alpha: 0.25);
      canvas.drawLine(toCanvas(la), toCanvas(lb), bonePaint);
    }

    final jointPaint = Paint();
    for (final landmark in frame.landmarks.values) {
      jointPaint.color = landmark.confidence >= minConfidence
          ? Colors.amberAccent
          : Colors.redAccent.withValues(alpha: 0.5);
      canvas.drawCircle(toCanvas(landmark), 6, jointPaint);
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter oldDelegate) =>
      oldDelegate.frame != frame || oldDelegate.mirror != mirror;
}
