import '../rep/pushup_counter.dart';
import 'recording.dart';

/// Kết quả chạy một bản ghi qua rep engine.
class ReplayResult {
  const ReplayResult({
    required this.recording,
    required this.counted,
    required this.events,
  });

  final Recording recording;
  final int counted;
  final List<RepEvent> events;

  int? get expected => recording.expectedCount;

  /// Dương = đếm thừa, âm = đếm thiếu.
  int? get error => switch (expected) {
    final expected? => counted - expected,
    null => null,
  };

  int get partialCount => events.whereType<PartialRep>().length;

  int rejectedCount(RejectReason reason) =>
      events.whereType<RejectedRep>().where((e) => e.reason == reason).length;
}

ReplayResult replay(
  Recording recording, {
  PushupConfig config = const PushupConfig(),
  PushupMode? mode,
}) {
  final counter = PushupCounter(mode: mode ?? recording.mode, config: config);
  final events = <RepEvent>[];
  for (final frame in recording.frames) {
    events.addAll(counter.update(frame).events);
  }
  return ReplayResult(
    recording: recording,
    counted: counter.count,
    events: events,
  );
}

/// Tổng hợp độ chính xác trên các bản ghi đã gắn nhãn.
class ReplaySummary {
  factory ReplaySummary(Iterable<ReplayResult> results) {
    final labeled = [
      for (final r in results)
        if (r.error != null) r,
    ];
    var expected = 0;
    var over = 0;
    var under = 0;
    var exact = 0;
    var withinOne = 0;
    for (final r in labeled) {
      final error = r.error!;
      expected += r.expected!;
      if (error > 0) over += error;
      if (error < 0) under -= error;
      if (error == 0) exact++;
      if (error.abs() <= 1) withinOne++;
    }
    return ReplaySummary._(
      recordings: labeled.length,
      expectedReps: expected,
      overcounted: over,
      undercounted: under,
      exact: exact,
      withinOne: withinOne,
    );
  }

  const ReplaySummary._({
    required this.recordings,
    required this.expectedReps,
    required this.overcounted,
    required this.undercounted,
    required this.exact,
    required this.withinOne,
  });

  final int recordings;
  final int expectedReps;
  final int overcounted;
  final int undercounted;

  /// Số bản ghi đếm đúng tuyệt đối.
  final int exact;

  /// Số bản ghi lệch không quá 1 rep (chỉ số OBO trong các bài báo).
  final int withinOne;

  /// 1 − (tổng số rep đếm sai / tổng số rep thật).
  double get accuracy =>
      expectedReps == 0 ? 0 : 1 - (overcounted + undercounted) / expectedReps;

  /// Sai số tuyệt đối trung bình (rep) mỗi bản ghi.
  double get meanAbsoluteError =>
      recordings == 0 ? 0 : (overcounted + undercounted) / recordings;
}
