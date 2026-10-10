import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/dataset/recording.dart';
import 'package:solo_pushing_up/dataset/recording_store.dart';
import 'package:solo_pushing_up/dataset/replay.dart';
import 'package:solo_pushing_up/pose/pose_frame.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

import 'package:solo_pushing_up/sim/synthetic_pushup.dart';

Recording recordingOf(
  AngleTrack track, {
  int? expected,
  PushupMode mode = PushupMode.standard,
  SyntheticBody body = const SyntheticBody(),
}) => Recording(
  source: 'synthetic',
  createdAt: DateTime(2026, 10, 9, 22, 15, 30),
  mode: mode,
  imageSize: const ImageSize(1080, 1920),
  expectedCount: expected,
  tags: const {'angle': 'ngang'},
  notes: 'test',
  frames: track.frames(body: body),
);

AngleTrack setOf(int reps) => AngleTrack()
  ..hold(170, 600)
  ..reps(reps)
  ..hold(170, 300);

void main() {
  test('ghi rồi đọc lại JSON giữ nguyên dữ liệu và kết quả đếm', () {
    final original = recordingOf(setOf(4), expected: 4);
    final decoded = Recording.decode(original.encode());

    expect(decoded.source, original.source);
    expect(decoded.createdAt, original.createdAt);
    expect(decoded.mode, original.mode);
    expect(decoded.expectedCount, 4);
    expect(decoded.tags, {'angle': 'ngang'});
    expect(decoded.notes, 'test');
    expect(decoded.frames, hasLength(original.frames.length));
    expect(
      decoded.frames.first[Joint.leftElbow]!.x,
      closeTo(original.frames.first[Joint.leftElbow]!.x, 0.05),
    );
    expect(replay(decoded).counted, replay(original).counted);
  });

  test('đọc được bản ghi thiếu khớp và có tên khớp lạ', () {
    final recording = Recording.decode('''
{"version":1,"source":"mediapipe-python-full","createdAt":"2026-10-09T22:00:00",
 "mode":"knee","expectedCount":null,"tags":{"video":"a.mp4"},"notes":"",
 "imageSize":[720,1280],
 "frames":[{"t":0,"lm":{}},{"t":33,"lm":{"leftElbow":[1,2,0.9],"leftPinky":[3,4,0.5]}}]}
''');

    expect(recording.mode, PushupMode.knee);
    expect(recording.expectedCount, isNull);
    expect(recording.frames.first.isEmpty, isTrue);
    expect(recording.frames.last.landmarks.keys, [Joint.leftElbow]);
  });

  test('từ chối phiên bản bản ghi không hỗ trợ', () {
    expect(
      () => Recording.decode('{"version":99,"imageSize":[1,1],"frames":[]}'),
      throwsFormatException,
    );
  });

  test('tổng hợp độ chính xác trên nhiều bản ghi', () {
    final results = [
      replay(recordingOf(setOf(5), expected: 5)), // đúng
      replay(recordingOf(setOf(5), expected: 6)), // thiếu 1
      replay(recordingOf(setOf(5), expected: 3)), // thừa 2
      replay(recordingOf(setOf(5))), // chưa gắn nhãn, bỏ qua
    ];
    final summary = ReplaySummary(results);

    expect(summary.recordings, 3);
    expect(summary.expectedReps, 14);
    expect(summary.overcounted, 2);
    expect(summary.undercounted, 1);
    expect(summary.exact, 1);
    expect(summary.withinOne, 2);
    expect(summary.accuracy, closeTo(1 - 3 / 14, 1e-9));
    expect(summary.meanAbsoluteError, closeTo(1, 1e-9));
  });

  test('tên file chứa thời gian, chế độ và số rep thật', () {
    expect(
      RecordingStore.fileName(recordingOf(setOf(1), expected: 15)),
      '20261009_221530_standard_15.json',
    );
  });
}
