import 'dart:math' as math;

import '../pose/pose_frame.dart';
import 'one_euro_filter.dart';

/// Tân binh = chống gối, Chiến binh = chuẩn (xem rules/cottruyen.md mục 1b).
enum PushupMode { knee, standard }

enum Posture { unknown, knee, standard }

enum CounterPhase {
  /// Chưa vào tư thế bắt đầu (tay thẳng đủ lâu).
  searching,

  /// Ở phía trên: tay thẳng hoặc đang đẩy lên sau một rep.
  top,

  /// Đang hạ người, chưa đủ sâu.
  goingDown,

  /// Đã xuống đủ sâu, chờ đẩy lên.
  bottom,
}

enum RejectReason { kneelingInStandardMode, bodyNotStraight }

sealed class RepEvent {
  const RepEvent(this.timestampMs, this.minElbowAngle);

  final int timestampMs;
  final double minElbowAngle;
}

/// Rep hợp lệ, đã được cộng vào [PushupCounter.count].
final class CountedRep extends RepEvent {
  const CountedRep({
    required int timestampMs,
    required double minElbowAngle,
    required this.index,
    required this.durationMs,
    required this.descentMs,
    required this.posture,
    required this.isDeep,
    required this.isFast,
    required this.isSlow,
    this.bodyAngle,
    this.formWarning = false,
    int? startMs,
  }) : startMs = startMs ?? timestampMs - durationMs,
       super(timestampMs, minElbowAngle);

  final int index;

  /// Chu kỳ đáy tới đáy (gồm cả lúc nghỉ giữa hai rep).
  final int durationMs;

  /// Lúc bắt đầu hạ người (đỉnh trước đáy). Khoảng nghỉ giữa hai rep là
  /// `startMs` của rep này trừ `timestampMs` của rep trước.
  final int startMs;

  /// Thời gian từ lúc rời tư thế cao tới điểm thấp nhất.
  final int descentMs;
  final Posture posture;
  final bool isDeep;
  final bool isFast;
  final bool isSlow;

  /// Góc thân trung vị lúc hạ người (`null` nếu không đo được).
  final double? bodyAngle;

  /// Vẫn tính rep nhưng nên nhắc giữ thân thẳng hơn (võng/chổng nhẹ).
  final bool formWarning;
}

/// Đủ biên độ nhưng sai tư thế: không được tính.
final class RejectedRep extends RepEvent {
  const RejectedRep(super.timestampMs, super.minElbowAngle, this.reason);

  final RejectReason reason;
}

/// Hạ người nhưng chưa đủ sâu đã đẩy lên: không được tính.
final class PartialRep extends RepEvent {
  const PartialRep(super.timestampMs, super.minElbowAngle);
}

/// Ngưỡng mặc định được chỉnh trên 97 clip RepCount + PushupBench
/// (dart run tool/replay.dart dataset/public/…).
class PushupConfig {
  const PushupConfig({
    this.minConfidence = 0.5,
    this.sideConfidenceGap = 0.2,
    this.readyAngle = 135,
    this.swingDeg = 20,
    this.maxValley = 120,
    this.minAmplitude = 30,
    this.rhythmCycles = 3,
    this.maxCycleMs = 4000,
    this.minPlausibleValley = 25,
    this.minCycleMs = 250,
    this.deepAngle = 75,
    this.straightBodyAngle = 145,
    this.formWarningBodyAngle = 165,
    this.kneelingKneeAngle = 140,
    this.readyHoldMs = 400,
    this.lostTimeoutMs = 1500,
    this.postureMemoryMs = 3000,
    this.fastRepMs = 1000,
    this.slowDescentMs = 2500,
    this.topPeakToleranceDeg = 3,
    this.angleMinCutoff = 1.5,
    this.angleBeta = 0.2,
    this.adaptive = true,
    this.calibrationReps = 2,
    this.depthSlack = 30,
    this.minPersonalValley = 95,
    this.minLegSegmentRatio = 1.2,
    this.minTorsoRatio = 1.3,
    this.maxUprightRatio = 1.5,
    this.minHipAngleForLegs = 120,
    this.minFoldedThighRatio = 1.4,
    this.frontViewRatio = 1.2,
    this.frontAmplitudeScale = 0.6,
    this.frontDepthSignal = true,
    this.frontDepthGain = 200,
    this.maxJumpRatio = 1.5,
    this.maxScaleChange = 0.7,
  });

  /// Khớp có độ tin cậy thấp hơn mức này coi như không thấy.
  final double minConfidence;

  /// Hai bên tay chênh độ tin cậy hơn mức này thì chỉ dùng bên rõ hơn,
  /// ngược lại lấy trung bình hai bên.
  final double sideConfidenceGap;

  /// Góc khuỷu tay (vai–khuỷu–cổ tay) từ mức này trở lên = tay thẳng,
  /// dùng để vào tư thế sẵn sàng và tính thời gian giữ.
  final double readyAngle;

  /// Góc phải đổi chiều ít nhất bấy nhiêu mới công nhận một đỉnh/đáy
  /// (lọc rung). Rep được tính ngay khi góc rời đáy đủ [swingDeg].
  final double swingDeg;

  /// Đáy (góc nhỏ nhất của rep) phải từ mức này trở xuống mới là đủ sâu.
  /// Giới hạn cứng chống rep nông, kể cả khi góc máy làm góc trên ảnh bị nén.
  final double maxValley;

  /// Đỉnh vừa rồi − đáy phải từ mức này trở lên mới là một rep. Tương đối
  /// theo đỉnh của chính người tập, nên đếm được cả khi mỏi tay không duỗi
  /// hết, tập nhanh, hay góc máy làm góc trên ảnh bị nén.
  final double minAmplitude;

  /// Chưa vào tư thế sẵn sàng mà đã có bấy nhiêu rep hợp lệ liên tiếp
  /// (mỗi rep cách nhau không quá [maxCycleMs]) thì bắt đầu đếm và tính bù
  /// các rep đó. Để người tập nhanh, không dừng giữ tay thẳng (hoặc vừa
  /// mất dấu giữa set) không bị mất rep.
  final int rhythmCycles;
  final int maxCycleMs;

  /// Đáy nhỏ hơn mức này là vô lý về mặt cơ thể (model nhận nhầm khớp,
  /// ví dụ 1–13° trên RepCount): bỏ qua, không phải rep.
  final double minPlausibleValley;

  /// Chu kỳ (đáy tới đáy) ngắn hơn mức này là vô lý (kỷ lục ~2 rep/giây):
  /// bỏ qua như nhiễu.
  final int minCycleMs;

  /// Góc khuỷu tay nhỏ nhất từ mức này trở xuống = rep sâu (đòn chí mạng).
  final double deepAngle;

  /// Góc vai–hông–mắt cá (hoặc vai–hông–gối) nhỏ hơn mức này = thân không
  /// thẳng rõ ràng: rep bị từ chối.
  final double straightBodyAngle;

  /// Nhỏ hơn mức này (nhưng chưa tới [straightBodyAngle]) = võng/chổng nhẹ:
  /// vẫn tính rep, kèm nhắc nhở. Trên bộ Mendeley (quay ngang), tư thế đúng
  /// cho 170–178°, tư thế xấu phần lớn 164–169°: từ chối hẳn sẽ oan người tập
  /// đúng, còn đếm thiếu là lời chê lớn nhất về Pushup RPG.
  final double formWarningBodyAngle;

  /// Góc hông–gối–mắt cá nhỏ hơn mức này = đang quỳ gối.
  final double kneelingKneeAngle;

  /// Giữ tay thẳng bấy lâu thì bắt đầu đếm (cách thứ hai: [rhythmCycles]).
  final int readyHoldMs;

  /// Mất dấu tay lâu hơn mức này thì quay về [CounterPhase.searching].
  final int lostTimeoutMs;

  /// Nhớ tư thế (quỳ / chuẩn) bấy lâu khi chân tạm khuất khỏi khung hình.
  final int postureMemoryMs;

  final int fastRepMs;
  final int slowDescentMs;

  /// Rep bắt đầu từ lần cuối góc khuỷu tay còn cách đỉnh trong khoảng này,
  /// để tính đủ thời gian hạ người chậm ngay từ lúc rời tư thế duỗi thẳng.
  final double topPeakToleranceDeg;
  final double angleMinCutoff;
  final double angleBeta;

  /// Sau [calibrationReps] rep hợp lệ, siết ngưỡng đủ sâu theo từng người:
  /// trung vị đáy + [depthSlack], trong khoảng [minPersonalValley]..[maxValley].
  /// Người vẫn xuống sâu tới 70° thì rep chỉ tới 105° sẽ bị coi là nông.
  final bool adaptive;
  final int calibrationReps;
  final double depthSlack;
  final double minPersonalValley;

  /// Chỉ đánh giá quỳ gối khi đùi và cẳng chân dài ít nhất bấy nhiêu lần
  /// cánh tay trên trên ảnh. Quay chính diện thì chân bị co ngắn, góc gối
  /// rất nhiễu: trên RepCount, bỏ điều kiện này làm 263 rep chuẩn bị coi là quỳ.
  /// Nhìn ngang, đùi ≈ 1,5 và cẳng chân ≈ 1,4 lần cánh tay trên.
  final double minLegSegmentRatio;

  /// Tương tự cho thân (vai–hông, nhìn ngang ≈ 1,7 lần cánh tay trên).
  final double minTorsoRatio;

  /// Hông thấp hơn vai (theo chiều dọc ảnh) quá bấy nhiêu lần cánh tay trên
  /// = thân đang dựng đứng (đứng, ngồi, quỳ nghỉ), không phải tư thế hít đất:
  /// co duỗi tay lúc này không được tính. Hít đất (kể cả quay chính diện) thì
  /// hông gần ngang vai trên ảnh.
  final double maxUprightRatio;

  /// Góc vai–hông–gối nhỏ hơn mức này mà đùi lại ngắn = chân "đoán bừa"
  /// (chân ngoài khung, ML Kit đặt gối/mắt cá ngay dưới hông, stu9_52).
  /// Lúc hít đất, kể cả chống gối, đùi nối tiếp đường thân. Khi đó không kết
  /// luận quỳ hay thân thẳng/không thẳng.
  final double minHipAngleForLegs;

  /// Khi đùi gập dưới [minHipAngleForLegs], đùi phải dài ít nhất bấy nhiêu
  /// lần cánh tay trên mới tin là chân thật (đùi thật nhìn ngang ≈ 1,5 lần;
  /// chân đoán bừa ngắn hơn). Giữ được việc bắt chổng mông thật.
  final double minFoldedThighRatio;

  /// Bề ngang vai / cánh tay trên lớn hơn mức này = đang quay chính diện.
  final double frontViewRatio;

  /// Ở góc chính diện, biên độ góc khuỷu tay trên ảnh bị nén: nhân
  /// [swingDeg] và [minAmplitude] với hệ số này.
  final double frontAmplitudeScale;

  /// Ở góc chính diện (máy đặt trước mặt, kiểu người chơi nhìn được màn
  /// hình), đếm bằng độ sâu: khoảng cách dọc vai–cổ tay chia bề ngang vai,
  /// thay cho góc khuỷu tay vốn bị nén mạnh khi nhìn thẳng. Đo trên 12 clip
  /// chính diện Mendeley: góc khuỷu đếm thiếu nhiều (clip 004 đếm 2/7).
  final bool frontDepthSignal;

  /// Quy đổi độ sâu ra góc tương đương: góc = 180 − gain × (1 − độ sâu tương
  /// đối). Nhìn thẳng, độ hạ người trông nông hơn thật nên gain > 180.
  final double frontDepthGain;

  /// Vai dịch chuyển quá bấy nhiêu lần cánh tay trên giữa hai khung liên
  /// tiếp, hoặc kích thước cơ thể đổi quá [maxScaleChange], thì coi như
  /// model đã nhảy sang người khác (nhiều người trong khung): theo dõi lại
  /// từ đầu thay vì nối tín hiệu của hai người thành rep giả.
  final double maxJumpRatio;
  final double maxScaleChange;
}

class CounterSnapshot {
  const CounterSnapshot({
    required this.count,
    required this.phase,
    required this.posture,
    required this.trackingLost,
    required this.events,
    required this.topThreshold,
    required this.bottomThreshold,
    required this.calibrated,
    this.elbowAngle,
    this.bodyAngle,
    this.holdMs = 0,
    this.plankHoldMs = 0,
  });

  /// Góc tay thẳng để vào tư thế sẵn sàng.
  final double topThreshold;

  /// Đáy phải sâu tới mức này (đã theo từng người nếu [calibrated]).
  final double bottomThreshold;
  final bool calibrated;

  final int count;
  final CounterPhase phase;
  final Posture posture;
  final bool trackingLost;

  /// Các rep kết thúc ở khung hình này.
  final List<RepEvent> events;
  final double? elbowAngle;
  final double? bodyAngle;

  /// Thời gian đang giữ tay thẳng (chỉ khác 0 ở [CounterPhase.top]).
  final int holdMs;

  /// Như [holdMs] nhưng chặt hơn: không đứng/quỳ thẳng người và thân thẳng
  /// (nếu thấy được). Dùng cho hành động ⏸ giữ tư thế cao trong game.
  final int plankHoldMs;
}

class _Side {
  const _Side(
    this.shoulder,
    this.elbow,
    this.wrist,
    this.hip,
    this.knee,
    this.ankle,
  );

  final Joint shoulder;
  final Joint elbow;
  final Joint wrist;
  final Joint hip;
  final Joint knee;
  final Joint ankle;
}

const _sides = [
  _Side(
    Joint.leftShoulder,
    Joint.leftElbow,
    Joint.leftWrist,
    Joint.leftHip,
    Joint.leftKnee,
    Joint.leftAnkle,
  ),
  _Side(
    Joint.rightShoulder,
    Joint.rightElbow,
    Joint.rightWrist,
    Joint.rightHip,
    Joint.rightKnee,
    Joint.rightAnkle,
  ),
];

/// Đếm push-up từ chuỗi [PoseFrame] theo các điểm đảo chiều (đỉnh/đáy)
/// của góc khuỷu tay.
///
/// Một rep = góc xuống tới đáy rồi đảo chiều đi lên ít nhất
/// [PushupConfig.swingDeg]; đáy phải đủ sâu ([PushupConfig.maxValley], hoặc
/// theo thói quen từng người) và đỉnh ngay trước − đáy ≥
/// [PushupConfig.minAmplitude]. Bắt đầu đếm khi giữ tay thẳng, hoặc khi đã
/// thấy [PushupConfig.rhythmCycles] rep liên tiếp (tính bù các rep đó).
///
/// Không bắt buộc thấy hông/chân suốt set: thiếu thì vẫn đếm, chỉ bỏ qua
/// bước kiểm tra tư thế (rules/review_appstore.md mục 3.1).
class PushupCounter {
  PushupCounter({
    this.mode = PushupMode.standard,
    this.config = const PushupConfig(),
  });

  PushupMode mode;
  final PushupConfig config;

  late final OneEuroFilter _elbowFilter = OneEuroFilter(
    minCutoff: config.angleMinCutoff,
    beta: config.angleBeta,
  );
  late final OneEuroFilter _bodyFilter = OneEuroFilter(
    minCutoff: config.angleMinCutoff,
    beta: config.angleBeta,
  );

  int _count = 0;
  bool _active = false;
  int? _lastSeenMs;
  int? _topSinceMs;
  int? _holdStartMs;
  int? _plankStartMs;
  double? _elbowAngle;
  double? _bodyAngle;

  Posture _lastPosture = Posture.unknown;
  int? _lastPostureMs;

  // Bộ dò điểm đảo chiều. `null` = chưa có mẫu nào từ lần reset gần nhất.
  bool? _rising;
  double _extreme = 0;
  int _extremeMs = 0;
  double? _lastPeak;
  int _lastPeakMs = 0;
  int? _lastValleyMs;

  // Tư thế quan sát được từ đỉnh vừa rồi tới đáy.
  // Bỏ phiếu theo từng khung: một khung nhiễu (ML Kit hay đoán bừa vị trí
  // gối/mắt cá bị che) không được làm hỏng cả rep.
  final List<double> _cycleBodyAngles = [];
  int _cycleKneeFrames = 0;
  int _cycleStandardFrames = 0;
  int _cycleFrames = 0;
  int _cycleUprightFrames = 0;

  /// Rep thấy được khi chưa bắt đầu đếm, chờ đủ nhịp để tính bù.
  final List<_Candidate> _pending = [];

  /// Trung bình trượt của tỉ lệ bề ngang vai / cánh tay trên (góc máy).
  double? _viewRatio;

  /// Đang đếm bằng độ sâu (góc chính diện) thay cho góc khuỷu tay.
  bool _usingDepth = false;
  int _viewSamples = 0;
  double? _shoulderWidth;
  double? _depthTop;
  final List<double> _recentDepths = [];

  double? _lastShoulderX;
  double? _lastShoulderY;
  double? _lastScale;

  final List<double> _recentValleys = [];
  late double _maxValley = config.maxValley;

  int get count => _count;

  CounterPhase get phase {
    if (!_active) return CounterPhase.searching;
    if (_rising ?? true) return CounterPhase.top;
    final a = _elbowAngle;
    return a != null && a <= _maxValley
        ? CounterPhase.bottom
        : CounterPhase.goingDown;
  }

  bool get calibrated =>
      config.adaptive && _recentValleys.length >= config.calibrationReps;

  void reset({PushupMode? mode}) {
    if (mode != null) this.mode = mode;
    _count = 0;
    _lastSeenMs = null;
    _lastPosture = Posture.unknown;
    _lastPostureMs = null;
    _recentValleys.clear();
    _maxValley = config.maxValley;
    _deactivate();
  }

  CounterSnapshot update(PoseFrame frame) {
    final t = frame.timestampMs;
    final events = <RepEvent>[];

    final rawElbow = _readElbowAngle(frame);
    if (rawElbow == null) {
      final lastSeen = _lastSeenMs;
      if (lastSeen != null && t - lastSeen > config.lostTimeoutMs) {
        // Mất dấu lâu: bắt đầu lại (giữ tay thẳng hoặc đủ nhịp mới đếm).
        if (_active || _rising != null) _deactivate();
      }
      return _snapshot(t, events, trackingLost: true);
    }
    _lastSeenMs = t;
    if (_jumpedToAnotherPerson(frame)) {
      _rising = null;
      _lastPeak = null;
      _lastValleyMs = null;
      _pending.clear();
      _resetCycle();
      _elbowFilter.reset();
      _bodyFilter.reset();
    }

    final seconds = t / 1000;
    // Chọn tín hiệu theo góc máy, không theo từng khung: khung thiếu cổ tay
    // ở góc chính diện chỉ là mất dấu tạm, không đổi qua đổi lại.
    final useDepth = config.frontDepthSignal && _isFrontView;
    if (useDepth != _usingDepth) {
      // Đổi tín hiệu: hai thang đo khác nhau, bắt đầu lại chu kỳ đang dở.
      _usingDepth = useDepth;
      _rising = null;
      _lastPeak = null;
      _lastValleyMs = null;
      _pending.clear();
      _resetCycle();
      _elbowFilter.reset();
    }
    final double signal;
    if (_usingDepth) {
      final depth = _frontDepthAngle(frame);
      if (depth == null) {
        _trackView(frame);
        return _snapshot(t, events, trackingLost: true);
      }
      signal = depth;
    } else {
      signal = rawElbow;
    }
    final a = _elbowFilter.filter(signal, seconds);
    _elbowAngle = a;

    final reading = _readPosture(frame);
    final rawBody = reading.bodyAngle;
    _bodyAngle = rawBody == null ? null : _bodyFilter.filter(rawBody, seconds);
    if (reading.posture != Posture.unknown) {
      _lastPosture = reading.posture;
      _lastPostureMs = t;
    }
    _trackPosture(reading.posture);
    _trackView(frame);
    _cycleFrames++;
    if (_isUpright(frame)) _cycleUprightFrames++;

    if (!_active) _checkReadyHold(t, a);

    final valley = _trackTurningPoints(t, a);
    if (valley != null) _onValley(t, valley, events);

    _updateHold(t, a);
    _updatePlank(t, frame);
    return _snapshot(t, events, trackingLost: false);
  }

  /// Bắt đầu đếm khi giữ tay thẳng đủ lâu.
  void _checkReadyHold(int t, double a) {
    if (a < config.readyAngle) {
      _topSinceMs = null;
      return;
    }
    final since = _topSinceMs ??= t;
    if (t - since < config.readyHoldMs) return;
    _active = true;
    _pending.clear();
    _holdStartMs = since;
    // Đếm từ tư thế này: đỉnh đầu tiên là đỉnh hiện tại.
    _rising = true;
    _extreme = a;
    _extremeMs = t;
    _lastPeak = null;
    _lastValleyMs = null;
    _resetCycle();
  }

  /// Trả về (góc, thời điểm) của đáy vừa được xác nhận, nếu có.
  ({double angle, int ms})? _trackTurningPoints(int t, double a) {
    final rising = _rising;
    if (rising == null) {
      _rising = true;
      _extreme = a;
      _extremeMs = t;
      return null;
    }
    if (rising) {
      if (a > _extreme) _extreme = a;
      // Lần cuối còn sát đỉnh = lúc bắt đầu hạ người (tính thời gian xuống).
      if (a >= _extreme - config.topPeakToleranceDeg) _extremeMs = t;
      if (a <= _extreme - _swing) {
        _lastPeak = _extreme;
        _lastPeakMs = _extremeMs;
        // Tư thế chỉ xét từ lúc bắt đầu hạ người tới đáy: động tác ở phía
        // trên (chạm chân, nghỉ, đổi tay) không làm rep bị từ chối.
        _resetCycle();
        _rising = false;
        _extreme = a;
        _extremeMs = t;
      }
      return null;
    }
    if (a < _extreme) {
      _extreme = a;
      _extremeMs = t;
    }
    if (a >= _extreme + _swing) {
      final valley = (angle: _extreme, ms: _extremeMs);
      _rising = true;
      _extreme = a;
      _extremeMs = t;
      return valley;
    }
    return null;
  }

  void _onValley(
    int t,
    ({double angle, int ms}) valley,
    List<RepEvent> events,
  ) {
    final peak = _lastPeak;
    final previousValleyMs = _lastValleyMs;
    // Đáy vô lý (nhận nhầm khớp) hoặc quá sát đáy trước: nhiễu, bỏ qua và
    // không lấy làm mốc chu kỳ.
    if (valley.angle < config.minPlausibleValley ||
        (previousValleyMs != null &&
            valley.ms - previousValleyMs < config.minCycleMs)) {
      _resetCycle();
      return;
    }
    _lastValleyMs = valley.ms;
    if (peak == null) {
      _resetCycle();
      return;
    }

    final amplitude = peak - valley.angle;
    final candidate = _Candidate(
      timestampMs: t,
      valley: valley.angle,
      startMs: _lastPeakMs,
      descentMs: valley.ms - _lastPeakMs,
      // Chu kỳ = đáy tới đáy; rep đầu tiên ước lượng bằng 2 × thời gian xuống.
      durationMs: previousValleyMs == null
          ? 2 * (valley.ms - _lastPeakMs)
          : valley.ms - previousValleyMs,
      posture: _cyclePosture(t),
      body: _median(_cycleBodyAngles),
      deepEnough: valley.angle <= _maxValley,
      bigEnough: amplitude >= config.minAmplitude * _viewScale,
      upright: _cycleFrames > 0 && _cycleUprightFrames * 2 > _cycleFrames,
    );
    _resetCycle();
    // Co duỗi tay khi đang đứng/ngồi/quỳ nghỉ: không phải rep, bỏ qua hẳn
    // (và cắt chuỗi nhịp đang gom).
    if (candidate.upright) {
      _pending.clear();
      return;
    }

    if (_active) {
      final event = _materialize(candidate);
      if (event != null) events.add(event);
      return;
    }

    // Chưa đếm: gom rep hợp lệ liên tiếp, đủ nhịp thì bắt đầu và tính bù.
    final lastPending = _pending.lastOrNull;
    if (!candidate.deepEnough ||
        !candidate.bigEnough ||
        (lastPending != null &&
            candidate.timestampMs - lastPending.timestampMs >
                config.maxCycleMs)) {
      _pending.clear();
    }
    if (candidate.deepEnough && candidate.bigEnough) _pending.add(candidate);
    if (_pending.length >= config.rhythmCycles) {
      _active = true;
      for (final pending in _pending) {
        final event = _materialize(pending);
        if (event != null) events.add(event);
      }
      _pending.clear();
    }
  }

  /// Biến một rep ứng viên thành sự kiện (và cộng số đếm nếu hợp lệ).
  RepEvent? _materialize(_Candidate c) {
    if (!c.deepEnough) {
      // Đổi chiều trên đáy nông: chỉ báo "chưa đủ sâu" khi thật sự có hạ người.
      return c.bigEnough || c.valley <= config.readyAngle
          ? PartialRep(c.timestampMs, c.valley)
          : null;
    }
    // Đủ sâu nhưng biên độ nhỏ (nảy ở đáy): không phải rep mới, bỏ qua.
    if (!c.bigEnough) return null;

    if (mode == PushupMode.standard && c.posture == Posture.knee) {
      return RejectedRep(
        c.timestampMs,
        c.valley,
        RejectReason.kneelingInStandardMode,
      );
    }
    final body = c.body;
    if (body != null && body < config.straightBodyAngle) {
      return RejectedRep(c.timestampMs, c.valley, RejectReason.bodyNotStraight);
    }

    _count++;
    _calibrate(c.valley);
    return CountedRep(
      timestampMs: c.timestampMs,
      minElbowAngle: c.valley,
      index: _count,
      durationMs: c.durationMs,
      startMs: c.startMs,
      descentMs: c.descentMs,
      posture: c.posture,
      isDeep: c.valley <= config.deepAngle,
      isFast: c.durationMs < config.fastRepMs,
      isSlow: c.descentMs >= config.slowDescentMs,
      bodyAngle: body,
      formWarning: body != null && body < config.formWarningBodyAngle,
    );
  }

  void _updateHold(int t, double a) {
    if (!_active) return;
    if ((_rising ?? false) && a >= config.readyAngle) {
      _holdStartMs ??= t;
    } else {
      _holdStartMs = null;
    }
  }

  void _updatePlank(int t, PoseFrame frame) {
    final body = _bodyAngle;
    final plank =
        _holdStartMs != null &&
        !_isUpright(frame) &&
        (body == null || body >= config.straightBodyAngle);
    if (plank) {
      _plankStartMs ??= t;
    } else {
      _plankStartMs = null;
    }
  }

  void _trackPosture(Posture posture) {
    final body = _bodyAngle;
    if (body != null) _cycleBodyAngles.add(body);
    if (posture == Posture.knee) _cycleKneeFrames++;
    if (posture == Posture.standard) _cycleStandardFrames++;
  }

  void _resetCycle() {
    _cycleBodyAngles.clear();
    _cycleKneeFrames = 0;
    _cycleStandardFrames = 0;
    _cycleFrames = 0;
    _cycleUprightFrames = 0;
  }

  /// Góc chính diện có vùng trễ: vào khi tỉ lệ vượt [frontViewRatio], chỉ
  /// thoát khi xuống dưới 80% mức đó. Tỉ lệ dao động khi hạ người, nếu không
  /// có vùng trễ bộ đếm sẽ đổi tín hiệu liên tục và mất rep.
  bool _isFrontView = false;

  /// Độ sâu ở góc chính diện quy về "góc tương đương": tay thẳng (vai cao
  /// nhất so với cổ tay gần đây) ≈ 180°, càng hạ người càng nhỏ. Nhờ vậy
  /// phần còn lại của bộ đếm (zigzag, rep nông, hiệu chỉnh) dùng lại nguyên.
  double? _frontDepthAngle(PoseFrame f) {
    bool ok(Landmark? l) => l != null && l.confidence >= config.minConfidence;
    final ls = f[Joint.leftShoulder];
    final rs = f[Joint.rightShoulder];
    // Bề ngang vai trượt chậm, bỏ khung model đặt hai vai chồng lên nhau.
    if (ok(ls) && ok(rs)) {
      final width = _dist(ls!, rs!);
      final w = _shoulderWidth;
      if (w == null) {
        _shoulderWidth = width;
      } else if (width > w * 0.6 && width < w * 1.6) {
        _shoulderWidth = w * 0.95 + width * 0.05;
      }
    }
    final reference = _shoulderWidth;
    if (reference == null || reference <= 0) return null;
    // Chỉ cần một bên thấy cả vai lẫn cổ tay (bên kia hay bị che khi hạ).
    final drops = [
      for (final side in _sides)
        if (f[side.shoulder] case final s? when ok(s))
          if (f[side.wrist] case final w? when ok(w)) w.y - s.y,
    ];
    if (drops.isEmpty) return null;
    final depth = drops.reduce((a, b) => a + b) / drops.length / reference;

    _recentDepths.add(depth);
    if (_recentDepths.length > 3) _recentDepths.removeAt(0);
    final d = _median(_recentDepths)!;
    final top = _depthTop;
    _depthTop = top == null || d > top ? d : top - (top - d) * 0.002;
    if (_depthTop! <= 0) return null;
    // Nhìn thẳng, độ hạ người trông nông hơn thật: hạ còn 60% ≈ 90°.
    return (180 - config.frontDepthGain * (1 - d / _depthTop!)).clamp(
      30.0,
      180.0,
    );
  }

  double get _viewScale =>
      _isFrontView && !_usingDepth ? config.frontAmplitudeScale : 1;

  double get _swing => config.swingDeg * _viewScale;

  void _trackView(PoseFrame f) {
    final left = f[Joint.leftShoulder];
    final right = f[Joint.rightShoulder];
    final upperArm = _upperArmLength(f);
    if (left == null ||
        right == null ||
        upperArm == null ||
        upperArm == 0 ||
        left.confidence < config.minConfidence ||
        right.confidence < config.minConfidence) {
      return;
    }
    final ratio = _dist(left, right) / upperArm;
    final previous = _viewRatio;
    // Lúc đầu lấy trung bình cộng để nhận ra góc máy ngay từ rep đầu tiên.
    _viewSamples++;
    final weight = math.max(0.05, 1 / _viewSamples);
    final smoothed = previous == null
        ? ratio
        : previous * (1 - weight) + ratio * weight;
    _viewRatio = smoothed;
    if (smoothed > config.frontViewRatio) {
      _isFrontView = true;
    } else if (smoothed < config.frontViewRatio * 0.8) {
      _isFrontView = false;
    }
  }

  bool _jumpedToAnotherPerson(PoseFrame f) {
    final scale = _upperArmLength(f);
    double? x;
    double? y;
    for (final side in _sides) {
      final shoulder = f[side.shoulder];
      if (shoulder != null && shoulder.confidence >= config.minConfidence) {
        x = shoulder.x;
        y = shoulder.y;
        break;
      }
    }
    final lastX = _lastShoulderX;
    final lastY = _lastShoulderY;
    final lastScale = _lastScale;
    var jumped = false;
    if (scale != null && x != null && y != null) {
      if (lastX != null && lastY != null && lastScale != null) {
        final dx = x - lastX;
        final dy = y - lastY;
        final moved = math.sqrt(dx * dx + dy * dy);
        final width = _shoulderWidth;
        jumped = _usingDepth && width != null
            // Chính diện: cánh tay trên bị co ngắn trên ảnh, đo bằng bề
            // ngang vai đã làm mượt; khung nhiễu không được tính là đổi người.
            ? moved > config.maxJumpRatio * width
            : moved > config.maxJumpRatio * lastScale ||
                  (scale - lastScale).abs() > config.maxScaleChange * lastScale;
      }
      _lastShoulderX = x;
      _lastShoulderY = y;
      _lastScale = scale;
    }
    return jumped;
  }

  /// Thân dựng đứng: hông thấp hơn vai nhiều so với cánh tay trên.
  bool _isUpright(PoseFrame f) {
    final reference = _upperArmLength(f);
    if (reference == null) return false;
    for (final side in _sides) {
      final shoulder = f[side.shoulder];
      final hip = f[side.hip];
      if (shoulder == null ||
          hip == null ||
          shoulder.confidence < config.minConfidence ||
          hip.confidence < config.minConfidence) {
        continue;
      }
      return hip.y - shoulder.y > config.maxUprightRatio * reference;
    }
    return false;
  }

  static double? _median(List<double> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort();
    return sorted[sorted.length ~/ 2];
  }

  Posture _cyclePosture(int t) {
    // Quỳ chỉ khi đa số khung thấy quỳ (và ít nhất 3 khung).
    if (_cycleKneeFrames >= 3 && _cycleKneeFrames > _cycleStandardFrames) {
      return Posture.knee;
    }
    if (_cycleStandardFrames > 0 || _cycleKneeFrames > 0) {
      return _cycleKneeFrames > _cycleStandardFrames
          ? _rememberedPosture(t)
          : Posture.standard;
    }
    return _rememberedPosture(t);
  }

  double? _readElbowAngle(PoseFrame f) {
    final readings = <({double angle, double confidence})>[];
    for (final side in _sides) {
      final confidence = _minConfidence(f, [
        side.shoulder,
        side.elbow,
        side.wrist,
      ]);
      if (confidence >= config.minConfidence) {
        readings.add((
          angle: angleDeg(f[side.shoulder]!, f[side.elbow]!, f[side.wrist]!),
          confidence: confidence,
        ));
      }
    }
    if (readings.isEmpty) return null;
    if (readings.length == 1) return readings.single.angle;

    final [a, b] = readings;
    if ((a.confidence - b.confidence).abs() > config.sideConfidenceGap) {
      return a.confidence > b.confidence ? a.angle : b.angle;
    }
    return (a.angle + b.angle) / 2;
  }

  ({Posture posture, double? bodyAngle}) _readPosture(PoseFrame f) {
    _Side? best;
    var bestConfidence = 0.0;
    for (final side in _sides) {
      final confidence = _minConfidence(f, [
        side.shoulder,
        side.hip,
        side.knee,
      ]);
      if (confidence > bestConfidence) {
        best = side;
        bestConfidence = confidence;
      }
    }
    if (best == null || bestConfidence < config.minConfidence) {
      return (posture: Posture.unknown, bodyAngle: null);
    }

    final shoulder = f[best.shoulder]!;
    final hip = f[best.hip]!;
    final knee = f[best.knee]!;
    final ankle = f[best.ankle];

    // Thước đo: cánh tay trên dài nhất đang thấy rõ. Chân/thân ngắn hơn
    // nhiều so với nó nghĩa là bị co ngắn do góc máy, không đáng tin.
    final reference = _upperArmLength(f);
    bool longEnough(Landmark a, Landmark b, double ratio) =>
        reference == null || _dist(a, b) >= ratio * reference;
    final torsoOk = longEnough(shoulder, hip, config.minTorsoRatio);
    // Đùi gập vuông khỏi thân mà lại ngắn: chân "đoán bừa", không kết luận.
    // (Chổng mông thật thì đùi vẫn dài bình thường, vẫn được kiểm tra.)
    if (angleDeg(shoulder, hip, knee) < config.minHipAngleForLegs &&
        !longEnough(hip, knee, config.minFoldedThighRatio)) {
      return (posture: Posture.unknown, bodyAngle: null);
    }

    if (ankle == null || ankle.confidence < config.minConfidence) {
      // Không thấy mắt cá: vẫn kiểm tra được thân thẳng tới gối,
      // nhưng không biết đang quỳ hay không.
      return (
        posture: Posture.unknown,
        bodyAngle: torsoOk ? angleDeg(shoulder, hip, knee) : null,
      );
    }
    // Đi dọc thân thì vai → hông → gối → mắt cá phải xa vai dần. Khi chân
    // ngoài khung, ML Kit vẫn "đoán" gối/mắt cá (độ tin cậy cao) nằm lẫn vào
    // vùng thân: thứ tự này bị phá, không dùng để kết luận quỳ.
    final orderedChain =
        _dist(shoulder, knee) > _dist(shoulder, hip) &&
        _dist(shoulder, ankle) > _dist(shoulder, knee);
    final legOk =
        orderedChain &&
        longEnough(hip, knee, config.minLegSegmentRatio) &&
        longEnough(knee, ankle, config.minLegSegmentRatio);
    if (!legOk) {
      return (posture: Posture.unknown, bodyAngle: null);
    }
    if (angleDeg(hip, knee, ankle) < config.kneelingKneeAngle) {
      return (
        posture: Posture.knee,
        bodyAngle: torsoOk ? angleDeg(shoulder, hip, knee) : null,
      );
    }
    return (
      posture: Posture.standard,
      bodyAngle: torsoOk ? angleDeg(shoulder, hip, ankle) : null,
    );
  }

  double? _upperArmLength(PoseFrame f) {
    double? longest;
    for (final side in _sides) {
      final shoulder = f[side.shoulder];
      final elbow = f[side.elbow];
      if (shoulder == null ||
          elbow == null ||
          shoulder.confidence < config.minConfidence ||
          elbow.confidence < config.minConfidence) {
        continue;
      }
      final length = _dist(shoulder, elbow);
      if (longest == null || length > longest) longest = length;
    }
    return longest;
  }

  static double _dist(Landmark a, Landmark b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  double _minConfidence(PoseFrame f, List<Joint> joints) {
    var result = 1.0;
    for (final joint in joints) {
      final confidence = f[joint]?.confidence ?? 0;
      if (confidence < result) result = confidence;
    }
    return result;
  }

  void _calibrate(double valley) {
    if (!config.adaptive) return;
    const window = 5;
    _recentValleys.add(valley);
    if (_recentValleys.length > window) _recentValleys.removeAt(0);
    if (!calibrated) return;
    final sorted = [..._recentValleys]..sort();
    final mid = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
    _maxValley = (median + config.depthSlack).clamp(
      config.minPersonalValley,
      config.maxValley,
    );
  }

  Posture _rememberedPosture(int t) {
    final at = _lastPostureMs;
    if (at == null || t - at > config.postureMemoryMs) return Posture.unknown;
    return _lastPosture;
  }

  void _deactivate() {
    _active = false;
    _pending.clear();
    _topSinceMs = null;
    _holdStartMs = null;
    _plankStartMs = null;
    _elbowAngle = null;
    _bodyAngle = null;
    _rising = null;
    _lastPeak = null;
    _lastValleyMs = null;
    _resetCycle();
    _elbowFilter.reset();
    _bodyFilter.reset();
  }

  CounterSnapshot _snapshot(
    int t,
    List<RepEvent> events, {
    required bool trackingLost,
  }) {
    final holdStart = _holdStartMs;
    final plankStart = _plankStartMs;
    final phase = this.phase;
    return CounterSnapshot(
      count: _count,
      phase: phase,
      topThreshold: config.readyAngle,
      bottomThreshold: _maxValley,
      calibrated: calibrated,
      posture: _rememberedPosture(t),
      trackingLost: trackingLost,
      events: events,
      elbowAngle: trackingLost ? null : _elbowAngle,
      bodyAngle: trackingLost ? null : _bodyAngle,
      holdMs: phase == CounterPhase.top && holdStart != null
          ? t - holdStart
          : 0,
      plankHoldMs:
          !trackingLost && phase == CounterPhase.top && plankStart != null
          ? t - plankStart
          : 0,
    );
  }
}

class _Candidate {
  const _Candidate({
    required this.timestampMs,
    required this.valley,
    required this.startMs,
    required this.descentMs,
    required this.durationMs,
    required this.posture,
    required this.body,
    required this.deepEnough,
    required this.bigEnough,
    required this.upright,
  });

  final int timestampMs;
  final double valley;
  final int startMs;
  final int descentMs;
  final int durationMs;
  final Posture posture;

  /// Góc thân trung vị lúc hạ người.
  final double? body;
  final bool deepEnough;
  final bool bigEnough;
  final bool upright;
}
