// Đo độ nhất quán giữa các góc máy khi CÙNG một lượt tập được quay đồng
// thời từ nhiều góc. Không cần nhãn số rep: góc ngang (side) dễ đếm nhất
// được dùng làm mốc so sánh.
//
// Lưu ý: bộ Mendeley KHÔNG quay đồng thời (mỗi góc là một lượt tập riêng,
// số chu kỳ khác nhau — đã kiểm tra bằng biểu đồ), nên không dùng được.
//
//   dart run tool/consistency.dart dataset/public/mendeley_form/recordings
//   dart run tool/consistency.dart <thư mục> --mode knee --verbose
import 'dart:io';

import 'package:solo_pushing_up/dataset/recording.dart';
import 'package:solo_pushing_up/dataset/replay.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

void main(List<String> args) {
  var directory = 'dataset/public/mendeley_form/recordings';
  var mode = PushupMode.knee;
  var verbose = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--mode':
        mode = PushupMode.values.byName(args[++i]);
      case '--verbose' || '-v':
        verbose = true;
      case final path:
        directory = path;
    }
  }

  // (người, tư thế) → góc máy → kết quả
  final groups = <String, Map<String, ReplayResult>>{};
  for (final file in Directory(directory).listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    final recording = Recording.decode(file.readAsStringSync());
    final key = '${recording.tags['subject']}_${recording.tags['form']}';
    final view = recording.tags['view'] ?? '?';
    groups.putIfAbsent(key, () => {})[view] = replay(recording, mode: mode);
  }

  const views = ['side', 'diagonal', 'front'];
  final diffs = {for (final v in views.skip(1)) v: <int>[]};
  final keys = groups.keys.toList()..sort();
  if (verbose) {
    stdout.writeln('nhóm            ngang  chéo  chính diện   (nông/từ chối)');
  }
  for (final key in keys) {
    final g = groups[key]!;
    final side = g['side'];
    if (verbose) {
      String cell(String v) {
        final r = g[v];
        if (r == null) return '   –';
        final rejected = r.events.whereType<RejectedRep>().length;
        return '${r.counted.toString().padLeft(4)} (${r.partialCount}/$rejected)';
      }

      stdout.writeln('${key.padRight(14)} ${views.map(cell).join('  ')}');
    }
    if (side == null) continue;
    for (final v in views.skip(1)) {
      final other = g[v];
      if (other != null) diffs[v]!.add(other.counted - side.counted);
    }
  }

  stdout.writeln('\nSo với góc ngang (chế độ ${mode.name}):');
  for (final MapEntry(key: view, value: d) in diffs.entries) {
    if (d.isEmpty) continue;
    final exact = d.where((x) => x == 0).length;
    final withinOne = d.where((x) => x.abs() <= 1).length;
    final mae = d.map((x) => x.abs()).reduce((a, b) => a + b) / d.length;
    final bias = d.reduce((a, b) => a + b) / d.length;
    stdout.writeln(
      '  ${view.padRight(9)} ${d.length} nhóm · khớp $exact/${d.length}'
      ' · lệch ≤1: $withinOne/${d.length} · lệch TB ${mae.toStringAsFixed(2)}'
      ' · thiên ${bias >= 0 ? '+' : ''}${bias.toStringAsFixed(2)} rep',
    );
  }
}
