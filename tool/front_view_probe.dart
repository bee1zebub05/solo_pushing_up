// Thăm dò góc quay chính diện (kiểu Pushup RPG đặt máy trước mặt).
// So bộ đếm hiện tại (góc khuỷu) với tín hiệu "độ sâu": khoảng cách dọc
// vai–cổ tay chia bề rộng vai.
//
//   dart run tool/front_view_probe.dart dataset/public/mendeley_form/recordings
import 'dart:io';
import 'dart:math' as math;

import 'package:solo_pushing_up/dataset/recording.dart';
import 'package:solo_pushing_up/dataset/replay.dart';
import 'package:solo_pushing_up/pose/pose_frame.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

/// Bề rộng vai trung vị của cả clip (ổn định hơn từng khung).
double medianShoulderWidth(List<PoseFrame> frames) {
  final widths = <double>[
    for (final f in frames)
      if (f[Joint.leftShoulder] case final l? when l.confidence >= 0.5)
        if (f[Joint.rightShoulder] case final r? when r.confidence >= 0.5)
          (l.x - r.x).abs(),
  ]..sort();
  return widths.isEmpty ? 1 : widths[widths.length ~/ 2];
}

double? depthSignal(PoseFrame f, double width) {
  final ls = f[Joint.leftShoulder], rs = f[Joint.rightShoulder];
  final lw = f[Joint.leftWrist], rw = f[Joint.rightWrist];
  if ([ls, rs, lw, rw].any((l) => l == null || l.confidence < 0.5)) {
    return null;
  }
  final shoulderY = (ls!.y + rs!.y) / 2;
  final wristY = (lw!.y + rw!.y) / 2;
  return (wristY - shoulderY) / width;
}

/// Đếm số chu kỳ xuống–lên bằng zigzag với ngưỡng [swing] (tương đối).
int zigzag(List<double> s, double swing) {
  if (s.isEmpty) return 0;
  var count = 0;
  var rising = true;
  var extreme = s.first;
  for (final v in s) {
    if (rising) {
      if (v > extreme) extreme = v;
      if (extreme - v > swing) {
        rising = false;
        extreme = v;
      }
    } else {
      if (v < extreme) extreme = v;
      if (v - extreme > swing) {
        rising = true;
        extreme = v;
        count++;
      }
    }
  }
  return count;
}

void main(List<String> args) {
  final dir = Directory(
    args.isEmpty ? 'dataset/public/mendeley_form/recordings' : args.first,
  );
  final rows = <String>[];
  for (final file in dir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.json'),
  )) {
    final rec = Recording.decode(file.readAsStringSync());
    final counted = replay(rec, mode: PushupMode.knee).counted;
    final width = medianShoulderWidth(rec.frames);
    final signal = [for (final f in rec.frames) ?depthSignal(f, width)];
    // Làm mượt trung bình trượt 5 khung.
    final smooth = [
      for (var i = 0; i < signal.length; i++)
        signal
                .sublist(math.max(0, i - 2), math.min(signal.length, i + 3))
                .reduce((a, b) => a + b) /
            (math.min(signal.length, i + 3) - math.max(0, i - 2)),
    ];
    final range = smooth.isEmpty
        ? 0.0
        : smooth.reduce(math.max) - smooth.reduce(math.min);
    final depthCount = zigzag(smooth, 0.3);
    final t = rec.tags;
    rows.add(
      '${t['subject']}\t${t['form']}\t${t['view']}\t$counted\t$depthCount\t${range.toStringAsFixed(2)}\t${signal.length}/${rec.frames.length}',
    );
  }
  rows.sort();
  stdout.writeln(
    'subject\tform\tview\tgoc_khuyu\tdo_sau\tbien_do\tkhung_co_vai_tay',
  );
  rows.forEach(stdout.writeln);
}
