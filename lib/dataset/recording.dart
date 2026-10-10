import 'dart:convert';

import '../pose/pose_frame.dart';
import '../rep/pushup_counter.dart';

/// Một set push-up đã ghi lại: chuỗi landmarks + đáp án (số rep thật).
///
/// Cùng định dạng JSON cho bản ghi từ app (ML Kit) và từ video
/// (tool/extract_pose.py, MediaPipe), để tool/replay.dart chạy lại được
/// qua rep engine mỗi khi chỉnh ngưỡng.
class Recording {
  const Recording({
    required this.source,
    required this.createdAt,
    required this.mode,
    required this.imageSize,
    required this.frames,
    this.expectedCount,
    this.tags = const {},
    this.notes = '',
  });

  static const formatVersion = 1;

  /// Nguồn landmarks, ví dụ `mlkit-android`, `mediapipe-python-full`.
  final String source;
  final DateTime createdAt;
  final PushupMode mode;
  final ImageSize imageSize;
  final List<PoseFrame> frames;

  /// Số rep thật do người dùng nhập. `null` = chưa gắn nhãn.
  final int? expectedCount;

  /// Điều kiện quay, ví dụ `{'angle': 'chéo', 'light': 'tối'}`.
  final Map<String, String> tags;
  final String notes;

  Duration get duration => frames.isEmpty
      ? Duration.zero
      : Duration(
          milliseconds: frames.last.timestampMs - frames.first.timestampMs,
        );

  Map<String, Object?> toJson() => {
    'version': formatVersion,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
    'mode': mode.name,
    'expectedCount': expectedCount,
    'tags': tags,
    'notes': notes,
    'imageSize': [imageSize.width, imageSize.height],
    'frames': [
      for (final frame in frames)
        {
          't': frame.timestampMs,
          'lm': {
            for (final MapEntry(key: joint, value: l)
                in frame.landmarks.entries)
              joint.name: [
                _round(l.x, 1),
                _round(l.y, 1),
                _round(l.confidence, 3),
              ],
          },
        },
    ],
  };

  factory Recording.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != formatVersion) {
      throw FormatException('Không hỗ trợ phiên bản bản ghi: $version');
    }
    final [width as num, height as num] = json['imageSize']! as List<Object?>;
    final imageSize = ImageSize(width.toDouble(), height.toDouble());

    return Recording(
      source: json['source']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
      mode: PushupMode.values.byName(json['mode']! as String),
      imageSize: imageSize,
      expectedCount: json['expectedCount'] as int?,
      tags: {
        for (final MapEntry(:key, :value)
            in ((json['tags'] as Map<String, Object?>?) ?? const {}).entries)
          key: '$value',
      },
      notes: (json['notes'] as String?) ?? '',
      frames: [
        for (final frame in json['frames']! as List<Object?>)
          _frameFromJson(frame! as Map<String, Object?>, imageSize),
      ],
    );
  }

  String encode() => const JsonEncoder.withIndent(null).convert(toJson());

  static Recording decode(String source) =>
      Recording.fromJson(jsonDecode(source) as Map<String, Object?>);

  static PoseFrame _frameFromJson(Map<String, Object?> json, ImageSize size) {
    final landmarks = <Joint, Landmark>{};
    for (final MapEntry(:key, :value)
        in (json['lm']! as Map<String, Object?>).entries) {
      final joint = _jointsByName[key];
      if (joint == null) continue;
      final [x as num, y as num, confidence as num] = value! as List<Object?>;
      landmarks[joint] = Landmark(
        x.toDouble(),
        y.toDouble(),
        confidence.toDouble(),
      );
    }
    return PoseFrame(
      timestampMs: json['t']! as int,
      landmarks: landmarks,
      imageSize: size,
    );
  }

  static final _jointsByName = {for (final j in Joint.values) j.name: j};

  static double _round(double value, int digits) =>
      double.parse(value.toStringAsFixed(digits));
}
