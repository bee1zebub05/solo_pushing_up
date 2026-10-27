import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/pose/pose_frame.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

import 'package:solo_pushing_up/sim/synthetic_pushup.dart';

/// Chạy toàn bộ khung hình qua bộ đếm, trả về mọi sự kiện và snapshot cuối.
({List<RepEvent> events, CounterSnapshot last}) run(
  PushupCounter counter,
  Iterable<PoseFrame> frames,
) {
  final events = <RepEvent>[];
  CounterSnapshot? last;
  for (final frame in frames) {
    last = counter.update(frame);
    events.addAll(last.events);
  }
  return (events: events, last: last!);
}

AngleTrack readyThen(void Function(AngleTrack track) build) {
  final track = AngleTrack()..hold(170, 600);
  build(track);
  return track..hold(170, 300);
}

void main() {
  group('đếm cơ bản', () {
    test('đếm đúng 10 rep chuẩn', () {
      final counter = PushupCounter();
      final result = run(counter, readyThen((t) => t.reps(10)).frames());

      expect(counter.count, 10);
      expect(result.events, hasLength(10));
      expect(result.events, everyElement(isA<CountedRep>()));
      // Rep 1.5 giây là rep thường: không nhanh, không chậm, không sâu.
      expect(
        result.events.cast<CountedRep>().where(
          (r) => r.isFast || r.isSlow || r.isDeep,
        ),
        isEmpty,
      );
    });

    test('không đếm khi chưa giữ tay thẳng ở tư thế bắt đầu', () {
      final counter = PushupCounter();
      final track = AngleTrack()
        // Đang chuẩn bị tư thế: tay co duỗi nhưng chưa giữ thẳng đủ lâu.
        ..rep(top: 170, bottom: 60, descentMs: 300, ascentMs: 300)
        ..rep(top: 170, bottom: 60, descentMs: 300, ascentMs: 300)
        ..hold(170, 600)
        ..rep()
        ..hold(170, 300);
      run(counter, track.frames());

      expect(counter.count, 1);
    });

    test('rep nông không được tính', () {
      final counter = PushupCounter();
      final result = run(
        counter,
        readyThen((t) => t.reps(5, bottom: 130)).frames(),
      );

      expect(counter.count, 0);
      expect(result.events, hasLength(5));
      expect(result.events, everyElement(isA<PartialRep>()));
    });

    test('nhiễu ±4° không làm đếm thừa', () {
      final counter = PushupCounter();
      final track = readyThen((t) => t.reps(5))..addNoise(4);
      run(counter, track.frames());

      expect(counter.count, 5);
    });

    test('rung quanh ngưỡng tay thẳng không tạo rep ảo', () {
      final counter = PushupCounter();
      final track = AngleTrack()..hold(170, 600);
      for (var i = 0; i < 30; i++) {
        track
          ..hold(146, 66)
          ..hold(154, 66);
      }
      final result = run(counter, track.frames());

      expect(counter.count, 0);
      expect(result.events.whereType<CountedRep>(), isEmpty);
    });
  });

  group('phân loại rep', () {
    test('rep nhanh', () {
      final counter = PushupCounter();
      final result = run(
        counter,
        readyThen((t) => t.reps(8, descentMs: 350, ascentMs: 350)).frames(),
      );

      expect(counter.count, 8);
      expect(
        result.events.cast<CountedRep>().every((r) => r.isFast && !r.isSlow),
        isTrue,
      );
    });

    test('rep chậm (xuống 3 giây)', () {
      final counter = PushupCounter();
      final result = run(
        counter,
        readyThen((t) => t.rep(descentMs: 3000, ascentMs: 1000)).frames(),
      );

      final rep = result.events.single as CountedRep;
      expect(rep.isSlow, isTrue);
      expect(rep.isFast, isFalse);
    });

    test('rep sâu', () {
      final counter = PushupCounter();
      final result = run(counter, readyThen((t) => t.rep(bottom: 60)).frames());

      expect((result.events.single as CountedRep).isDeep, isTrue);
    });

    test('rep vừa đủ không phải rep sâu', () {
      final counter = PushupCounter();
      final result = run(counter, readyThen((t) => t.rep(bottom: 90)).frames());

      expect((result.events.single as CountedRep).isDeep, isFalse);
    });
  });

  group('chế độ Tân binh / Chiến binh', () {
    const kneeling = SyntheticBody(posture: SyntheticPosture.knee);

    test('quỳ gối ở chế độ Chiến binh bị từ chối', () {
      final counter = PushupCounter(mode: PushupMode.standard);
      final result = run(
        counter,
        readyThen((t) => t.reps(3)).frames(body: kneeling),
      );

      expect(counter.count, 0);
      expect(
        result.events.cast<RejectedRep>().map((r) => r.reason),
        everyElement(RejectReason.kneelingInStandardMode),
      );
    });

    test('quỳ gối ở chế độ Tân binh được tính', () {
      final counter = PushupCounter(mode: PushupMode.knee);
      final result = run(
        counter,
        readyThen((t) => t.reps(3)).frames(body: kneeling),
      );

      expect(counter.count, 3);
      expect(
        result.events.cast<CountedRep>().map((r) => r.posture),
        everyElement(Posture.knee),
      );
    });

    test(
      'làm chuẩn ở chế độ Tân binh vẫn được tính, ghi nhận tư thế chuẩn',
      () {
        final counter = PushupCounter(mode: PushupMode.knee);
        final result = run(counter, readyThen((t) => t.reps(3)).frames());

        expect(counter.count, 3);
        expect(
          result.events.cast<CountedRep>().map((r) => r.posture),
          everyElement(Posture.standard),
        );
      },
    );

    test('đổi chế độ bằng reset thì xoá số đếm', () {
      final counter = PushupCounter(mode: PushupMode.knee);
      run(counter, readyThen((t) => t.reps(2)).frames());
      counter.reset(mode: PushupMode.standard);

      expect(counter.count, 0);
      expect(counter.mode, PushupMode.standard);
      expect(counter.phase, CounterPhase.searching);
    });
  });

  group('tư thế thân', () {
    for (final (name, sag) in [('hông võng', 250.0), ('chổng mông', -250.0)]) {
      test('$name bị từ chối', () {
        final counter = PushupCounter();
        final result = run(
          counter,
          readyThen((t) => t.reps(3)).frames(body: SyntheticBody(hipSag: sag)),
        );

        expect(counter.count, 0);
        expect(
          result.events.cast<RejectedRep>().map((r) => r.reason),
          everyElement(RejectReason.bodyNotStraight),
        );
      });
    }

    test('hông hơi lệch một chút vẫn được tính', () {
      final counter = PushupCounter();
      run(
        counter,
        readyThen((t) => t.reps(3))
            .frames(body: const SyntheticBody(hipSag: 60)),
      );

      expect(counter.count, 3);
    });

    test('không thấy hông và chân vẫn đếm (camera chính diện, phòng nhỏ)', () {
      final counter = PushupCounter();
      const upperBodyOnly = SyntheticBody(
        overrides: {
          Joint.leftHip: 0.1,
          Joint.rightHip: 0.1,
          Joint.leftKnee: 0.1,
          Joint.rightKnee: 0.1,
          Joint.leftAnkle: 0.1,
          Joint.rightAnkle: 0.1,
        },
      );
      final result = run(
        counter,
        readyThen((t) => t.reps(4)).frames(body: upperBodyOnly),
      );

      expect(counter.count, 4);
      expect(
        result.events.cast<CountedRep>().map((r) => r.posture),
        everyElement(Posture.unknown),
      );
    });
  });

  group('mất dấu', () {
    test('một bên tay ra khỏi khung hình vẫn đếm bằng bên còn lại', () {
      final counter = PushupCounter();
      const leftArmHidden = SyntheticBody(
        overrides: {
          Joint.leftShoulder: 0.1,
          Joint.leftElbow: 0.1,
          Joint.leftWrist: 0.1,
        },
      );
      run(counter, readyThen((t) => t.reps(5)).frames(body: leftArmHidden));

      expect(counter.count, 5);
    });

    test('mất dấu ngắn giữa set thì đếm tiếp', () {
      final counter = PushupCounter();
      final first = readyThen((t) => t.reps(3));
      final firstFrames = first.frames();
      final gapStart = first.durationMs;
      const gapMs = 600;
      final gap = [
        for (var t = gapStart; t < gapStart + gapMs; t += frameStepMs)
          emptyFrame(t),
      ];
      final second =
          (AngleTrack()
                ..reps(3)
                ..hold(170, 300))
              .frames(startMs: gapStart + gapMs);

      final result = run(counter, [...firstFrames, ...gap, ...second]);

      expect(counter.count, 6);
      expect(result.last.trackingLost, isFalse);
    });

    test('mất dấu lâu thì phải vào lại tư thế bắt đầu', () {
      final counter = PushupCounter();
      final first = readyThen((t) => t.reps(2));
      final gapStart = first.durationMs;
      const gapMs = 3000;
      final gap = [
        for (var t = gapStart; t < gapStart + gapMs; t += frameStepMs)
          emptyFrame(t),
      ];
      final lost = run(counter, [...first.frames(), ...gap]).last;
      expect(lost.trackingLost, isTrue);
      expect(lost.phase, CounterPhase.searching);

      // Quay lại và rep ngay, chưa giữ tay thẳng: không được tính.
      final resumed =
          (AngleTrack()
                ..rep()
                ..hold(170, 600)
                ..rep()
                ..hold(170, 300))
              .frames(startMs: gapStart + gapMs);
      run(counter, resumed);

      expect(counter.count, 3);
    });
  });

  group('đếm theo đỉnh/đáy tương đối', () {
    test('mỏi tay không duỗi hết vẫn được đếm', () {
      final counter = PushupCounter();
      run(
        counter,
        readyThen(
          (t) => t
            ..reps(2)
            // Mỏi tay: không còn duỗi thẳng hết, chỉ lên tới 145°.
            ..reps(4, top: 145),
        ).frames(),
      );

      expect(counter.count, 6);
    });

    test('tập nhanh không duỗi hết tay', () {
      final counter = PushupCounter();
      run(
        counter,
        readyThen(
          (t) =>
              t.reps(10, top: 150, bottom: 85, descentMs: 300, ascentMs: 300),
        ).frames(),
      );

      expect(counter.count, 10);
    });

    test('góc máy làm góc khuỷu tay trên ảnh bị nén', () {
      final counter = PushupCounter();
      run(counter, readyThen((t) => t.reps(5, top: 150, bottom: 110)).frames());

      expect(counter.count, 5);
    });

    test('nảy ở đáy (lên một chút rồi xuống lại) vẫn là một rep', () {
      final counter = PushupCounter();
      // 170 → 80 → 105 → 80 rồi mới đẩy lên hẳn.
      final track = AngleTrack()
        ..hold(170, 600)
        ..moveTo(80, 750)
        ..moveTo(105, 300)
        ..moveTo(80, 300)
        ..moveTo(170, 750)
        ..hold(170, 300);
      run(counter, track.frames());

      expect(counter.count, 1);
    });
  });

  group('độ sâu theo từng người', () {
    AngleTrack deepThenShallow() => readyThen(
      (t) => t
        ..reps(3, bottom: 70)
        // Người này vẫn xuống tới 70°, rep chỉ tới 108° là nông với họ.
        ..rep(bottom: 108),
    );

    test('rep nông hơn hẳn thói quen của người tập không được tính', () {
      final counter = PushupCounter();
      final result = run(counter, deepThenShallow().frames());

      expect(counter.count, 3);
      expect(result.last.calibrated, isTrue);
      expect(result.last.bottomThreshold, lessThan(108));
      expect(result.events.last, isA<PartialRep>());
    });

    test('tắt tự chỉnh thì chỉ dùng ngưỡng sâu mặc định', () {
      final counter = PushupCounter(
        config: const PushupConfig(adaptive: false),
      );
      run(counter, deepThenShallow().frames());

      expect(counter.count, 4);
    });

    test('sau khi tự chỉnh, rep nông vẫn không được tính', () {
      final counter = PushupCounter();
      final result = run(
        counter,
        readyThen(
          (t) => t
            ..reps(3)
            ..reps(3, bottom: 125),
        ).frames(),
      );

      expect(counter.count, 3);
      expect(result.events.whereType<PartialRep>(), hasLength(3));
      expect(result.last.bottomThreshold, lessThanOrEqualTo(115));
    });

    test('chưa đủ rep thì giữ ngưỡng mặc định', () {
      final counter = PushupCounter();
      final result = run(counter, readyThen((t) => t.rep()).frames());

      expect(result.last.calibrated, isFalse);
      expect(result.last.bottomThreshold, const PushupConfig().maxValley);
    });

    test('reset xoá hiệu chỉnh (người khác tập)', () {
      final counter = PushupCounter();
      run(counter, readyThen((t) => t.reps(3)).frames());
      expect(counter.calibrated, isTrue);

      counter.reset();
      expect(counter.calibrated, isFalse);
    });
  });

  group('góc máy chính diện', () {
    // Biên độ nhỏ (25°) vì góc khuỷu tay trên ảnh bị nén khi quay chính diện.
    AngleTrack compressed() => AngleTrack()
      ..hold(150, 600)
      ..reps(6, top: 115, bottom: 90, descentMs: 400, ascentMs: 400)
      ..hold(115, 300);

    /// Máy đặt trước mặt (người chơi nhìn được màn hình): hai vai rộng,
    /// khuỷu bè ra hai bên, vai hạ xuống gần cổ tay theo độ sâu [depth]
    /// (khoảng cách dọc vai–cổ tay chia bề ngang vai).
    PoseFrame facing(double depth, int t) {
      const wristY = 800.0;
      final shoulderY = wristY - depth * 300;
      Landmark at(double x, double y) => Landmark(x, y, 0.95);
      return PoseFrame(
        timestampMs: t,
        imageSize: syntheticImageSize,
        landmarks: {
          Joint.nose: at(700, shoulderY + 60),
          Joint.leftShoulder: at(850, shoulderY),
          Joint.rightShoulder: at(550, shoulderY),
          Joint.leftElbow: at(960, (shoulderY + wristY) / 2),
          Joint.rightElbow: at(440, (shoulderY + wristY) / 2),
          Joint.leftWrist: at(870, wristY),
          Joint.rightWrist: at(530, wristY),
          Joint.leftHip: at(800, shoulderY - 160),
          Joint.rightHip: at(600, shoulderY - 160),
        },
      );
    }

    List<PoseFrame> facingSet(int reps, {double bottom = 0.5}) {
      final depths = <double>[
        for (var i = 0; i < 30; i++) 1.3,
        for (var r = 0; r < reps; r++)
          for (var i = 0; i < 36; i++)
            bottom +
                (1.3 - bottom) * (0.5 + 0.5 * math.cos(i / 36 * 2 * math.pi)),
        for (var i = 0; i < 15; i++) 1.3,
      ];
      return [
        for (var i = 0; i < depths.length; i++)
          facing(depths[i], i * frameStepMs),
      ];
    }

    test('máy đặt trước mặt: đếm bằng độ sâu vai–cổ tay', () {
      for (final mode in PushupMode.values) {
        final counter = PushupCounter(mode: mode);
        run(counter, facingSet(6));

        expect(counter.count, 6, reason: mode.name);
      }
    });

    test('máy đặt trước mặt: hạ người quá ít là rep nông', () {
      final counter = PushupCounter(mode: PushupMode.knee);
      final result = run(counter, facingSet(5, bottom: 0.95));

      expect(counter.count, 0);
      expect(result.events.whereType<PartialRep>(), isNotEmpty);
    });

    test('cùng biên độ đó khi quay ngang thì không đếm (quá nông)', () {
      final counter = PushupCounter(mode: PushupMode.knee);
      run(counter, compressed().frames());

      // Chỉ lần hạ đầu tiên (từ tư thế giữ 150° xuống 90°) là rep thật.
      expect(counter.count, lessThanOrEqualTo(1));
    });
  });

  group('không phải lúc hít đất', () {
    /// Đứng thẳng: hông thấp hơn vai cả một chiều dài thân.
    PoseFrame standing(PoseFrame f) {
      final shoulder = f[Joint.leftShoulder]!;
      Landmark below(double dy) => Landmark(shoulder.x, shoulder.y + dy, 0.9);
      return PoseFrame(
        timestampMs: f.timestampMs,
        imageSize: f.imageSize,
        landmarks: {
          ...f.landmarks,
          Joint.leftHip: below(340),
          Joint.rightHip: below(340),
          Joint.leftKnee: below(640),
          Joint.rightKnee: below(640),
          Joint.leftAnkle: below(920),
          Joint.rightAnkle: below(920),
        },
      );
    }

    test('đứng duỗi thẳng tay không phải giữ plank', () {
      final counter = PushupCounter();
      final frames = (AngleTrack()..hold(170, 2500)).frames().map(standing);
      final result = run(counter, frames);

      expect(result.last.plankHoldMs, 0);
    });

    test('co duỗi tay khi đang đứng không được tính', () {
      final counter = PushupCounter(mode: PushupMode.knee);
      final frames = readyThen((t) => t.reps(5)).frames().map(standing);
      final result = run(counter, frames);

      expect(counter.count, 0);
      expect(result.events.whereType<CountedRep>(), isEmpty);
    });

    test('model nhảy sang người khác giữa set không sinh rep giả', () {
      final counter = PushupCounter();
      final track = readyThen((t) => t.reps(4));
      final frames = track.frames();
      // Giữa set, toạ độ nhảy sang một người khác đứng xa hơn (nhỏ hơn, lệch chỗ).
      final jumpAt = frames.length ~/ 2;
      final shifted = [
        for (final (i, f) in frames.indexed)
          i < jumpAt
              ? f
              : PoseFrame(
                  timestampMs: f.timestampMs,
                  imageSize: f.imageSize,
                  landmarks: {
                    for (final MapEntry(key: j, value: l)
                        in f.landmarks.entries)
                      j: Landmark(l.x * 0.3 + 50, l.y * 0.3 + 20, l.confidence),
                  },
                ),
      ];
      run(counter, shifted);

      // Không đếm thừa: tối đa bằng số rep thật.
      expect(counter.count, lessThanOrEqualTo(4));
    });
  });

  group('giữ tư thế cao', () {
    test('báo thời gian giữ khi tay thẳng', () {
      final counter = PushupCounter();
      final result = run(counter, (AngleTrack()..hold(170, 2500)).frames());

      expect(result.last.phase, CounterPhase.top);
      expect(result.last.holdMs, greaterThanOrEqualTo(2300));
      // Tính từ lúc bộ đếm vào trạng thái sẵn sàng (sau ~400 ms giữ).
      expect(result.last.plankHoldMs, greaterThanOrEqualTo(2000));
    });

    test('thời gian giữ về 0 khi bắt đầu hạ người', () {
      final counter = PushupCounter();
      final track = AngleTrack()
        ..hold(170, 1500)
        ..hold(130, 200);
      final result = run(counter, track.frames());

      expect(result.last.phase, CounterPhase.goingDown);
      expect(result.last.holdMs, 0);
    });
  });
}
