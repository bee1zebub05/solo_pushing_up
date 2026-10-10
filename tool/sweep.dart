// Dò tham số của rep engine trên một thư mục bản ghi, in các tổ hợp tốt nhất.
//
//   dart run tool/sweep.dart dataset/public/repcount/recordings
//
// Chỉ dùng để gợi ý ngưỡng; giá trị chọn cuối cùng vẫn phải qua unit test
// (đặc biệt test rep nông) và kiểm tra trên bản ghi từ app.
import 'dart:io';

import 'package:solo_pushing_up/dataset/recording.dart';
import 'package:solo_pushing_up/dataset/replay.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'dataset/recordings' : args.first);
  // Dò trên split=train, báo thêm kết quả split=test để thấy có overfit không.
  final all = [
    for (final f in dir.listSync().whereType<File>())
      if (f.path.endsWith('.json')) Recording.decode(f.readAsStringSync()),
  ].where((r) => r.expectedCount != null).toList();
  final hasSplit = all.any((r) => r.tags.containsKey('split'));
  final recordings = hasSplit
      ? all.where((r) => r.tags['split'] == 'train').toList()
      : all;
  final held = hasSplit
      ? all.where((r) => r.tags['split'] == 'test').toList()
      : <Recording>[];
  stdout.writeln(
    '${recordings.length} bản ghi để dò, ${held.length} để kiểm tra',
  );

  final results = <(double, String, ReplaySummary, PushupConfig)>[];
  for (final scale in [1.0, 0.85, 0.7, 0.6, 0.5]) {
    for (final ratio in [1.0, 1.2, 1.5]) {
      final config = PushupConfig(
        frontAmplitudeScale: scale,
        frontViewRatio: ratio,
      );
      final summary = ReplaySummary([
        for (final r in recordings)
          replay(r, config: config, mode: PushupMode.knee),
      ]);
      results.add((
        summary.accuracy,
        'scale=$scale ratio=$ratio',
        summary,
        config,
      ));
    }
  }

  results.sort((a, b) => b.$1.compareTo(a.$1));
  for (final (accuracy, label, s, config) in results.take(15)) {
    final test = held.isEmpty
        ? ''
        : '  | test ${(ReplaySummary([for (final r in held) replay(r, config: config, mode: PushupMode.knee)]).accuracy * 100).toStringAsFixed(1)}%';
    stdout.writeln(
      '${(accuracy * 100).toStringAsFixed(1)}%  +${s.overcounted}/-${s.undercounted}'
      '  đúng ${s.exact}  ≤1 ${s.withinOne}$test   $label',
    );
  }
}
