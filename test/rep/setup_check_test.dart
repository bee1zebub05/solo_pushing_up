import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/pose/pose_frame.dart';
import 'package:solo_pushing_up/rep/setup_check.dart';
import 'package:solo_pushing_up/sim/synthetic_pushup.dart';

/// Khung hình nhìn chính diện: hai vai cách xa nhau, cánh tay thẳng đứng.
PoseFrame frontViewFrame() => PoseFrame(
  timestampMs: 0,
  imageSize: const ImageSize(720, 1280),
  landmarks: const {
    Joint.leftShoulder: Landmark(250, 500, 0.9),
    Joint.rightShoulder: Landmark(470, 500, 0.9),
    Joint.leftElbow: Landmark(240, 650, 0.9),
    Joint.rightElbow: Landmark(480, 650, 0.9),
    Joint.leftWrist: Landmark(240, 800, 0.9),
    Joint.rightWrist: Landmark(480, 800, 0.9),
  },
);

PoseFrame withBrightness(PoseFrame f, double brightness) => PoseFrame(
  timestampMs: f.timestampMs,
  landmarks: f.landmarks,
  imageSize: f.imageSize,
  brightness: brightness,
);

PoseFrame scaled(PoseFrame f, double factor) => PoseFrame(
  timestampMs: f.timestampMs,
  imageSize: f.imageSize,
  landmarks: {
    for (final MapEntry(key: j, value: l) in f.landmarks.entries)
      j: Landmark(
        f.imageSize.width / 2 + (l.x - f.imageSize.width / 2) * factor,
        f.imageSize.height / 2 + (l.y - f.imageSize.height / 2) * factor,
        l.confidence,
      ),
  },
);

void main() {
  final checker = SetupChecker();
  final side = syntheticFrame(170, 0);

  test('máy trước mặt, đủ sáng: không có vấn đề', () {
    expect(checker.checkFrame(withBrightness(frontViewFrame(), 120)), isEmpty);
  });

  test('không có người', () {
    expect(checker.checkFrame(emptyFrame(0)), {SetupIssue.noPerson});
  });

  test('không thấy tay', () {
    final noArms = syntheticFrame(
      170,
      0,
      body: const SyntheticBody(
        overrides: {Joint.leftWrist: 0.1, Joint.rightWrist: 0.1},
      ),
    );
    expect(checker.checkFrame(noArms), {SetupIssue.armsNotVisible});
  });

  test('máy đặt trước mặt: không nhắc gì về góc máy', () {
    expect(
      checker.checkFrame(frontViewFrame()),
      isNot(contains(SetupIssue.notFacing)),
    );
  });

  test('máy đặt ngang: nhắc đặt trước mặt (không chặn)', () {
    final issues = checker.checkFrame(side);
    expect(issues, contains(SetupIssue.notFacing));
    expect(SetupIssue.notFacing.blocking, isFalse);
  });

  test('ảnh tối', () {
    expect(
      checker.checkFrame(withBrightness(side, 20)),
      contains(SetupIssue.tooDark),
    );
  });

  test('quá xa và quá gần', () {
    expect(checker.checkFrame(scaled(side, 0.2)), contains(SetupIssue.tooFar));
    expect(
      checker.checkFrame(scaled(frontViewFrame(), 3)),
      contains(SetupIssue.tooClose),
    );
  });

  test('sát mép ảnh', () {
    final atEdge = PoseFrame(
      timestampMs: 0,
      imageSize: const ImageSize(720, 1280),
      landmarks: const {
        Joint.leftShoulder: Landmark(300, 500, 0.9),
        Joint.leftElbow: Landmark(300, 650, 0.9),
        Joint.leftWrist: Landmark(300, 1275, 0.9),
      },
    );
    expect(checker.checkFrame(atEdge), contains(SetupIssue.cutOffEdge));
  });

  test('lọc nhấp nháy: một khung lỗi lẻ không bị báo', () {
    final stable = SetupChecker();
    Set<SetupIssue> last = {};
    for (var i = 0; i < 15; i++) {
      last = stable.update(i == 7 ? emptyFrame(i) : frontViewFrame());
    }
    expect(last, isEmpty);

    for (var i = 0; i < 15; i++) {
      last = stable.update(emptyFrame(i));
    }
    expect(last, {SetupIssue.noPerson});
  });
}
