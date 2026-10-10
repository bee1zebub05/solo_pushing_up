// Chạy mọi bản ghi trong một thư mục qua rep engine hiện tại và in bảng sai số.
//
//   dart run tool/replay.dart                     # mặc định dataset/recordings
//   dart run tool/replay.dart <thư mục> --verbose  # in từng rep
//   dart run tool/replay.dart --min-accuracy 0.95  # exit 1 nếu dưới ngưỡng
//   dart run tool/replay.dart --no-adaptive        # tắt ngưỡng tự chỉnh để so sánh
//   dart run tool/replay.dart <thư mục> --where split=test  # chỉ các bản ghi có tag này
//   dart run tool/replay.dart <thư mục> --mode knee  # chấp nhận cả chống gối: đo độ chính xác đếm thuần
import 'dart:io';

import 'package:solo_pushing_up/dataset/recording.dart';
import 'package:solo_pushing_up/dataset/replay.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

void main(List<String> args) {
  var directory = 'dataset/recordings';
  var verbose = false;
  double? minAccuracy;
  var adaptive = true;
  final where = <String, String>{};
  PushupMode? modeOverride;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--verbose' || '-v':
        verbose = true;
      case '--where':
        final [key, value] = args[++i].split('=');
        where[key] = value;
      case '--mode':
        modeOverride = PushupMode.values.byName(args[++i]);
      case '--no-adaptive':
        adaptive = false;
      case '--min-accuracy':
        minAccuracy = double.parse(args[++i]);
      case '--help' || '-h':
        stdout.writeln(
          'dart run tool/replay.dart [thư mục] [--verbose] [--no-adaptive] [--where split=test] [--mode knee|standard] [--min-accuracy 0.95]',
        );
        return;
      case final path:
        directory = path;
    }
  }

  final dir = Directory(directory);
  if (!dir.existsSync()) {
    stderr.writeln('Không tìm thấy thư mục $directory');
    exitCode = 2;
    return;
  }
  final files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stdout.writeln('Chưa có bản ghi nào trong $directory');
    return;
  }

  final results = <ReplayResult>[];
  final rows = <List<String>>[];
  for (final file in files) {
    final name = file.uri.pathSegments.last;
    final Recording recording;
    try {
      recording = Recording.decode(file.readAsStringSync());
    } on FormatException catch (e) {
      stderr.writeln('Bỏ qua $name: ${e.message}');
      continue;
    }
    if (where.entries.any((w) => recording.tags[w.key] != w.value)) continue;
    final result = replay(
      recording,
      config: PushupConfig(adaptive: adaptive),
      mode: modeOverride,
    );
    results.add(result);
    rows.add(_row(name, result));
    if (verbose) _printEvents(name, result);
  }

  _printTable(rows);
  final summary = ReplaySummary(results);
  _printSummary(summary, results.length);

  if (minAccuracy != null &&
      summary.recordings > 0 &&
      summary.accuracy < minAccuracy) {
    stderr.writeln(
      'Độ chính xác ${_percent(summary.accuracy)} dưới ngưỡng ${_percent(minAccuracy)}',
    );
    exitCode = 1;
  }
}

const _headers = [
  'Bản ghi',
  'Chế độ',
  'Thật',
  'Đếm',
  'Lệch',
  'Nông',
  'Quỳ',
  'Thân',
  'Thời lượng',
  'Điều kiện',
];

List<String> _row(String name, ReplayResult r) {
  final recording = r.recording;
  final error = r.error;
  return [
    name,
    recording.mode == PushupMode.knee ? 'tân binh' : 'chiến binh',
    '${r.expected ?? '?'}',
    '${r.counted}',
    switch (error) {
      null => '?',
      0 => '0',
      > 0 => '+$error',
      _ => '$error',
    },
    '${r.partialCount}',
    '${r.rejectedCount(RejectReason.kneelingInStandardMode)}',
    '${r.rejectedCount(RejectReason.bodyNotStraight)}',
    '${(recording.duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
    recording.tags.values.join(', '),
  ];
}

void _printTable(List<List<String>> rows) {
  final widths = [
    for (var c = 0; c < _headers.length; c++)
      [
        _headers[c],
        ...rows.map((r) => r[c]),
      ].fold<int>(0, (w, cell) => cell.length > w ? cell.length : w),
  ];
  String line(List<String> cells) => [
    for (var c = 0; c < cells.length; c++)
      c == 0 || c == cells.length - 1
          ? cells[c].padRight(widths[c])
          : cells[c].padLeft(widths[c]),
  ].join('  ');

  stdout.writeln(line(_headers));
  stdout.writeln(widths.map((w) => '-' * w).join('  '));
  for (final row in rows) {
    stdout.writeln(line(row));
  }
}

void _printSummary(ReplaySummary s, int total) {
  stdout.writeln();
  if (s.recordings == 0) {
    stdout.writeln(
      '$total bản ghi, chưa bản nào có số rep thật (expectedCount).',
    );
    return;
  }
  stdout
    ..writeln('Bản ghi có đáp án: ${s.recordings}/$total')
    ..writeln('Tổng rep thật:     ${s.expectedReps}')
    ..writeln('Đếm thừa / thiếu:  +${s.overcounted} / -${s.undercounted}')
    ..writeln('Độ chính xác:      ${_percent(s.accuracy)}')
    ..writeln(
      'Sai số TB / set:   ${s.meanAbsoluteError.toStringAsFixed(2)} rep',
    )
    ..writeln(
      'Đúng tuyệt đối:    ${s.exact}/${s.recordings}'
      '   Lệch ≤1: ${s.withinOne}/${s.recordings}',
    );
}

void _printEvents(String name, ReplayResult r) {
  stdout.writeln('— $name');
  for (final event in r.events) {
    final time = (event.timestampMs / 1000).toStringAsFixed(2).padLeft(7);
    final angle = event.minElbowAngle.toStringAsFixed(0);
    final text = switch (event) {
      CountedRep() =>
        '#${event.index} ${(event.durationMs / 1000).toStringAsFixed(2)}s'
            '${event.isDeep ? ' sâu' : ''}${event.isFast ? ' nhanh' : ''}'
            '${event.isSlow ? ' chậm' : ''} (${event.posture.name})',
      PartialRep() => 'nông',
      RejectedRep() => 'từ chối: ${event.reason.name}',
    };
    stdout.writeln('  $time  góc min $angle°  $text');
  }
}

String _percent(double v) => '${(v * 100).toStringAsFixed(1)}%';
