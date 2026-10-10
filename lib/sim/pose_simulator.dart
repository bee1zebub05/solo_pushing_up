import 'dart:async';

import '../pose/pose_frame.dart';
import 'synthetic_pushup.dart';

/// Một kịch bản hít đất giả lập, dùng để thử app mà không cần người tập.
class SimScenario {
  const SimScenario({
    required this.name,
    required this.expectation,
    required this.build,
    this.sideView = false,
  });

  final String name;

  /// Kết quả mong đợi, hiện cho người thử đối chiếu.
  final String expectation;
  final List<PoseFrame> Function() build;

  /// Kịch bản cần thấy chân (quỳ gối, võng hông) thì giữ góc ngang; còn lại
  /// phát như máy dựng trước mặt người tập, đúng cách đặt máy khuyên dùng.
  final bool sideView;

  /// Khung hình sẽ phát.
  List<PoseFrame> frames() {
    final side = build();
    return sideView ? side : [for (final f in side) toFrontView(f)];
  }
}

AngleTrack _ready() => AngleTrack()..hold(170, 1000);

List<PoseFrame> _set(
  void Function(AngleTrack track) build, {
  SyntheticBody body = const SyntheticBody(),
}) {
  final track = _ready();
  build(track);
  track.hold(170, 1500);
  return track.frames(body: body);
}

/// Nối các đoạn khung hình, đánh lại thời gian liên tục.
List<PoseFrame> _concat(List<List<PoseFrame>> parts) {
  final result = <PoseFrame>[];
  var offset = 0;
  for (final part in parts) {
    if (part.isEmpty) continue;
    final start = part.first.timestampMs;
    for (final f in part) {
      result.add(
        PoseFrame(
          timestampMs: offset + f.timestampMs - start,
          landmarks: f.landmarks,
          imageSize: f.imageSize,
        ),
      );
    }
    offset = result.last.timestampMs + frameStepMs;
  }
  return result;
}

List<PoseFrame> _empty(int ms) => [
  for (var t = 0; t < ms; t += frameStepMs) emptyFrame(t),
];

final simScenarios = <SimScenario>[
  SimScenario(
    name: 'Chuẩn ×10',
    expectation: 'Đếm 10',
    build: () => _set((t) => t.reps(10)),
  ),
  SimScenario(
    name: 'Nhanh ×8',
    expectation: 'Đếm 8, mỗi rep có nhãn NHANH',
    build: () => _set((t) => t.reps(8, descentMs: 350, ascentMs: 350)),
  ),
  SimScenario(
    name: 'Chậm ×3',
    expectation: 'Đếm 3, mỗi rep có nhãn CHẬM',
    build: () => _set((t) => t.reps(3, descentMs: 3000, ascentMs: 1000)),
  ),
  SimScenario(
    name: 'Sâu ×5',
    expectation: 'Đếm 5, mỗi rep có nhãn SÂU',
    build: () => _set((t) => t.reps(5, bottom: 60)),
  ),
  SimScenario(
    name: 'Nông ×5',
    expectation: 'Đếm 0, báo "Chưa đủ sâu"',
    build: () => _set((t) => t.reps(5, bottom: 130)),
  ),
  SimScenario(
    name: 'Quỳ gối ×5 (máy ngang)',
    sideView: true,
    expectation: 'Chiến binh: 0 (báo duỗi chân) · Tân binh: 5',
    build: () => _set(
      (t) => t.reps(5),
      body: const SyntheticBody(posture: SyntheticPosture.knee),
    ),
  ),
  SimScenario(
    name: 'Võng hông ×5 (máy ngang)',
    sideView: true,
    expectation: 'Đếm 0, báo "Giữ thân thẳng"',
    build: () => _set((t) => t.reps(5), body: const SyntheticBody(hipSag: 250)),
  ),
  SimScenario(
    name: 'Rung nhiễu ×10',
    expectation: 'Đếm 10 dù góc khớp rung ±5°',
    build: () {
      final track = _ready()
        ..reps(10)
        ..hold(170, 1500)
        ..addNoise(5);
      return track.frames();
    },
  ),
  SimScenario(
    name: 'Mất dấu giữa set',
    expectation: 'Đếm 6 (3 + mất dấu 0.6s + 3)',
    build: () => _concat([
      (_ready()..reps(3)).frames(),
      _empty(600),
      (AngleTrack()
            ..reps(3)
            ..hold(170, 1500))
          .frames(),
    ]),
  ),
  SimScenario(
    name: 'Chuẩn bị lộn xộn',
    expectation: 'Đếm 3 (bỏ qua động tác lúc chưa vào tư thế)',
    build: () {
      final track = AngleTrack();
      // 2 lần co duỗi lúc vào tư thế: chưa đủ nhịp (3 rep) để bắt đầu đếm.
      for (var i = 0; i < 2; i++) {
        track.rep(top: 170, bottom: 60, descentMs: 300, ascentMs: 300);
      }
      track
        ..hold(170, 1000)
        ..reps(3)
        ..hold(170, 1500);
      return track.frames();
    },
  ),
  SimScenario(
    name: 'Giữ plank 5s',
    expectation: 'Đếm 0, đồng hồ giữ chạy tới 5s',
    build: () => (AngleTrack()..hold(170, 5500)).frames(),
  ),
];

/// Phát khung hình của một kịch bản theo thời gian thực, thay cho camera.
class PoseSimulator {
  PoseSimulator({required this.onFrame, this.onDone});

  final void Function(PoseFrame frame) onFrame;

  /// Gọi khi kịch bản phát hết (không gọi khi bị [stop] giữa chừng).
  final void Function()? onDone;
  final Stopwatch _clock = Stopwatch()..start();

  Timer? _timer;
  SimScenario? _scenario;
  double _progress = 0;

  SimScenario? get scenario => _scenario;
  bool get isPlaying => _timer != null;

  /// 0..1, tiến độ của kịch bản đang phát.
  double get progress => _progress;

  void play(SimScenario scenario) {
    stop();
    _scenario = scenario;
    _progress = 0;
    final frames = scenario.frames();
    // Thời gian tăng liên tục qua các lần phát, giống camera thật.
    final base = _clock.elapsedMilliseconds;
    var index = 0;
    _timer = Timer.periodic(const Duration(milliseconds: frameStepMs), (_) {
      if (index >= frames.length) {
        stop();
        onDone?.call();
        return;
      }
      final frame = frames[index++];
      _progress = index / frames.length;
      onFrame(
        PoseFrame(
          timestampMs: base + frame.timestampMs,
          landmarks: frame.landmarks,
          imageSize: frame.imageSize,
        ),
      );
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
