import 'dart:convert';
import 'dart:io';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';

import '../pose/pose_camera.dart';
import '../pose/pose_frame.dart';
import '../rep/pushup_counter.dart';
import 'recording.dart';

/// Chạy ảnh tách từ video có nhãn (tool/export_frames.py, đẩy sang máy bằng
/// tool/push_eval.ps1) qua đúng ML Kit của app, lưu thành bản ghi để
/// `dart run tool/replay.dart` chấm điểm. Đo đúng pipeline thật thay vì
/// MediaPipe trên máy tính.
/// App không đọc được ảnh mẫu do adb đẩy vào (Android 14+).
class EvaluationAccessException implements Exception {
  const EvaluationAccessException();
}

class MlKitDatasetEvaluator {
  static Future<Directory> _base() async =>
      (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
      await getApplicationDocumentsDirectory();

  /// Các thư mục có thể chứa clip (mỗi clip: ảnh 000001.jpg… + meta.json).
  /// Android 14+ không cho app đọc thư mục do adb tạo trong bộ nhớ ngoài,
  /// nên còn đọc bộ nhớ trong (chép vào bằng `adb shell run-as`, bản debug).
  static Future<List<Directory>> framesDirectories() async => [
    Directory('${(await _base()).path}/eval_frames'),
    Directory('${(await getApplicationSupportDirectory()).path}/eval_frames'),
  ];

  static Future<Directory> outputDirectory({bool accurate = false}) async =>
      Directory(
        '${(await _base()).path}/recordings_eval${accurate ? '_accurate' : ''}',
      ).create(recursive: true);

  /// Trả về số clip đã xử lý. [onProgress] nhận (clip đang chạy, tỉ lệ 0..1).
  /// [accurate]: dùng model "accurate" của ML Kit thay cho "base" (app đang
  /// dùng), để so độ chính xác và tốc độ.
  static Future<int> run({
    required void Function(String clip, double progress) onProgress,
    bool Function()? isCancelled,
    bool accurate = false,
  }) async {
    final clips = <Directory>[];
    for (final dir in await framesDirectories()) {
      if (!dir.existsSync()) continue;
      try {
        clips.addAll(
          dir.listSync().whereType<Directory>().where(
            (d) => File('${d.path}/meta.json').existsSync(),
          ),
        );
      } on FileSystemException {
        throw const EvaluationAccessException();
      }
    }
    if (clips.isEmpty) return 0;
    clips.sort((a, b) => a.path.compareTo(b.path));
    final outDir = await outputDirectory(accurate: accurate);

    var done = 0;
    for (final (index, clipDir) in clips.indexed) {
      if (isCancelled?.call() ?? false) break;
      final meta = jsonDecode(
        File('${clipDir.path}/meta.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final clip = meta['clip']! as String;
      final out = File('${outDir.path}/$clip.json');
      if (out.existsSync()) {
        done++;
        continue;
      }

      final timestamps = (meta['timestampsMs']! as List<Object?>).cast<int>();
      final [width as num, height as num] = meta['imageSize']! as List<Object?>;
      final size = ImageSize(width.toDouble(), height.toDouble());

      // Detector mới cho mỗi clip: chế độ stream bám theo người giữa các
      // khung liên tiếp, giống camera thật.
      final detector = PoseDetector(
        options: PoseDetectorOptions(
          mode: PoseDetectionMode.stream,
          model: accurate
              ? PoseDetectionModel.accurate
              : PoseDetectionModel.base,
        ),
      );
      final frames = <PoseFrame>[];
      final processingMs = <int>[];
      final stopwatch = Stopwatch();
      try {
        for (final (i, t) in timestamps.indexed) {
          final path =
              '${clipDir.path}/${(i + 1).toString().padLeft(6, '0')}.jpg';
          stopwatch
            ..reset()
            ..start();
          final poses = await detector.processImage(
            InputImage.fromFilePath(path),
          );
          processingMs.add(stopwatch.elapsedMilliseconds);
          frames.add(
            PoseFrame(
              timestampMs: t,
              landmarks: landmarksFromPose(poses.firstOrNull),
              imageSize: size,
            ),
          );
          if (i % 20 == 0) {
            onProgress(clip, (index + i / timestamps.length) / clips.length);
          }
        }
      } finally {
        await detector.close();
      }

      final recording = Recording(
        source:
            'mlkit-${accurate ? 'accurate' : 'base'}-${Platform.operatingSystem}-eval',
        createdAt: DateTime.now(),
        mode: PushupMode.values.byName((meta['mode'] as String?) ?? 'standard'),
        imageSize: size,
        expectedCount: meta['expectedCount'] as int?,
        tags: {
          for (final MapEntry(:key, :value)
              in ((meta['tags'] as Map<String, Object?>?) ?? const {}).entries)
            key: '$value',
          // Thời gian ML Kit xử lý một ảnh (gồm đọc file JPEG), để so máy.
          'mlMsMedian': '${_percentile(processingMs, 0.5)}',
          'mlMsP90': '${_percentile(processingMs, 0.9)}',
          'device': Platform.localHostname,
        },
        frames: frames,
      );
      await out.writeAsString(recording.encode());
      done++;
    }
    onProgress('', 1);
    return done;
  }

  static int _percentile(List<int> values, double p) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    return sorted[((sorted.length - 1) * p).round()];
  }
}
