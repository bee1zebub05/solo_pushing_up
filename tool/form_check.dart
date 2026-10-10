// Đo chống gian lận trên bản ghi có nhãn tư thế đúng/sai (tag form=good|bad),
// ví dụ bộ Mendeley: tư thế xấu là võng hông / chổng mông.
//
//   dart run tool/form_check.dart dataset/public/mendeley_form/recordings
//
// Lý tưởng: tư thế đúng gần như không bị từ chối, tư thế xấu bị từ chối nhiều.
import 'dart:io';

import 'package:solo_pushing_up/dataset/recording.dart';
import 'package:solo_pushing_up/dataset/replay.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

void main(List<String> args) {
  final directory = args.isEmpty
      ? 'dataset/public/mendeley_form/recordings'
      : args.first;

  // (form, view) → [đếm, từ chối thân, nông, số clip, nhắc nhở]
  final stats = <(String, String), List<int>>{};
  for (final file in Directory(directory).listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    final recording = Recording.decode(file.readAsStringSync());
    final form = recording.tags['form'];
    if (form == null) continue;
    final view = recording.tags['view'] ?? '?';
    final result = replay(recording, mode: PushupMode.standard);
    final s = stats.putIfAbsent((form, view), () => [0, 0, 0, 0, 0]);
    s[0] += result.counted;
    s[1] += result.rejectedCount(RejectReason.bodyNotStraight);
    s[2] += result.partialCount;
    s[3]++;
    s[4] += result.events
        .whereType<CountedRep>()
        .where((e) => e.formWarning)
        .length;
  }

  stdout.writeln(
    'tư thế  góc máy    clip   tính  từ chối(thân)  nông   % từ chối  % nhắc thân',
  );
  for (final form in ['good', 'bad']) {
    for (final view in ['side', 'diagonal', 'front']) {
      final s = stats[(form, view)];
      if (s == null) continue;
      final [counted, rejected, partial, clips, warned] = s;
      final total = counted + rejected;
      final rate = total == 0 ? 0.0 : rejected / total;
      stdout.writeln(
        '${form.padRight(6)}  ${view.padRight(9)}  ${clips.toString().padLeft(4)}'
        '  ${counted.toString().padLeft(5)}  ${rejected.toString().padLeft(13)}'
        '  ${partial.toString().padLeft(4)}   ${(rate * 100).toStringAsFixed(0).padLeft(7)}%'
        '  ${(counted == 0 ? 0 : warned / counted * 100).toStringAsFixed(0).padLeft(9)}%',
      );
    }
  }
}
