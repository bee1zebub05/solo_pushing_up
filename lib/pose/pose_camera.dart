import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'pose_frame.dart';

const _jointTypes = {
  Joint.nose: PoseLandmarkType.nose,
  Joint.leftShoulder: PoseLandmarkType.leftShoulder,
  Joint.rightShoulder: PoseLandmarkType.rightShoulder,
  Joint.leftElbow: PoseLandmarkType.leftElbow,
  Joint.rightElbow: PoseLandmarkType.rightElbow,
  Joint.leftWrist: PoseLandmarkType.leftWrist,
  Joint.rightWrist: PoseLandmarkType.rightWrist,
  Joint.leftHip: PoseLandmarkType.leftHip,
  Joint.rightHip: PoseLandmarkType.rightHip,
  Joint.leftKnee: PoseLandmarkType.leftKnee,
  Joint.rightKnee: PoseLandmarkType.rightKnee,
  Joint.leftAnkle: PoseLandmarkType.leftAnkle,
  Joint.rightAnkle: PoseLandmarkType.rightAnkle,
};

/// Chuyển kết quả ML Kit sang các khớp mà rep engine dùng.
Map<Joint, Landmark> landmarksFromPose(Pose? pose) {
  if (pose == null) return const {};
  return {
    for (final MapEntry(key: joint, value: type) in _jointTypes.entries)
      if (pose.landmarks[type] case final landmark?)
        joint: Landmark(landmark.x, landmark.y, landmark.likelihood),
  };
}

const _deviceOrientationDegrees = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Camera + ML Kit Pose Detection → [PoseFrame].
///
/// Bản prototype: frame đi qua platform channel sang Dart rồi lại sang native
/// cho ML Kit. Bản phát hành nên chuyển hẳn sang plugin native
/// (rules/congnghe.md mục 5).
class PoseCamera {
  PoseCamera({required this.onFrame});

  final void Function(PoseFrame frame) onFrame;

  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );
  final Stopwatch _clock = Stopwatch()..start();

  CameraController? _controller;
  CameraDescription? _camera;
  bool _busy = false;

  /// Hàng đợi bật/tắt camera, để các lần khởi tạo không bao giờ chồng nhau.
  ///
  /// Android dùng `camera_android` (Camera2) thay cho CameraX mặc định:
  /// camera_android_camerax 0.7.5 crash "Unsupported value:
  /// ProcessCameraProvider" khi khởi tạo lại camera trong cùng phiên
  /// (flutter/flutter#176687, #180497).
  Future<void> _queue = Future.value();

  CameraController? get controller => _controller;

  bool get isFrontCamera => _camera?.lensDirection == CameraLensDirection.front;

  /// Khung xương có cần lật gương để khớp preview camera trước không.
  /// Android: luồng ảnh không lật nhưng preview lật → cần lật. iOS:
  /// camera_avfoundation đã lật sẵn luồng ảnh camera trước
  /// (`isVideoMirrored`), toạ độ ML Kit đã khớp preview → không lật nữa.
  bool get overlayNeedsMirror => isFrontCamera && !Platform.isIOS;

  Future<void> start(CameraDescription camera) =>
      _enqueue(() => _start(camera));

  Future<void> stop() => _enqueue(_stop);

  Future<void> dispose() async {
    await stop();
    await _detector.close();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.catchError((_) {});
    return result;
  }

  Future<void> _start(CameraDescription camera) async {
    await _stop();
    final controller = CameraController(
      camera,
      // low (320×240 trên Android) cho khoảng 19 FPS so với 9–11 FPS ở medium
      // trên OPPO CPH2159 (bản profile). Model pose chỉ nhận ảnh ~256 px nên
      // độ phân giải cao hơn ít lợi; cần kiểm chứng lại khi đứng xa 2 m.
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    _camera = camera;
    _controller = controller;
    await controller.initialize();
    await controller.startImageStream(_onImage);
  }

  Future<void> _stop() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  Future<void> _onImage(CameraImage image) async {
    // Bỏ frame khi frame trước chưa xử lý xong, để không bị trễ dồn.
    if (_busy) return;
    final controller = _controller;
    final camera = _camera;
    if (controller == null || camera == null) return;

    final inputImage = _toInputImage(image, camera, controller);
    if (inputImage == null) return;

    _busy = true;
    try {
      final timestampMs = _clock.elapsedMilliseconds;
      final poses = await _detector.processImage(inputImage);
      final processingMs = _clock.elapsedMilliseconds - timestampMs;
      if (_controller != controller) return;

      final rotation = inputImage.metadata!.rotation;
      final sideways =
          rotation == InputImageRotation.rotation90deg ||
          rotation == InputImageRotation.rotation270deg;
      final width = image.width.toDouble();
      final height = image.height.toDouble();

      onFrame(
        PoseFrame(
          timestampMs: timestampMs,
          imageSize: sideways
              ? ImageSize(height, width)
              : ImageSize(width, height),
          landmarks: landmarksFromPose(poses.firstOrNull),
          brightness: _brightness(image),
          processingMs: processingMs,
        ),
      );
    } finally {
      _busy = false;
    }
  }

  /// Độ sáng trung bình 0..255, lấy mẫu thưa để gần như không tốn thời gian.
  static double? _brightness(CameraImage image) {
    final bytes = image.planes.first.bytes;
    // NV21: w×h byte đầu là kênh độ sáng Y. BGRA: lấy kênh G của mỗi điểm ảnh.
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;
    final pixels = image.width * image.height;
    final end = isBgra
        ? bytes.length
        : (pixels < bytes.length ? pixels : bytes.length);
    const step = 97; // số lẻ để không trùng chu kỳ hàng ảnh
    var sum = 0;
    var n = 0;
    for (var i = isBgra ? 1 : 0; i < end; i += isBgra ? step * 4 : step) {
      sum += bytes[i];
      n++;
    }
    return n == 0 ? null : sum / n;
  }

  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription camera,
    CameraController controller,
  ) {
    final sensorOrientation = camera.sensorOrientation;
    final InputImageRotation? rotation;
    if (Platform.isIOS) {
      // camera_avfoundation (≥ 0.10) đã xoay luồng ảnh theo hướng cầm máy
      // (dọc hay ngang), nên ảnh tới đây luôn đứng thẳng. `sensorOrientation`
      // trên iOS luôn là 90 (giá trị cố định của plugin), dùng nó sẽ xoay thừa
      // 90° và đảo khung ảnh. Cần soát trên iPhone thật cả dọc lẫn ngang.
      rotation = InputImageRotation.rotation0deg;
    } else {
      final deviceDegrees =
          _deviceOrientationDegrees[controller.value.deviceOrientation];
      if (deviceDegrees == null) return null;
      final compensation = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + deviceDegrees) % 360
          : (sensorOrientation - deviceDegrees + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;

    final format = Platform.isAndroid
        ? (image.format.group == ImageFormatGroup.nv21
              ? InputImageFormat.nv21
              : null)
        : InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (format == null || image.planes.length != 1) return null;

    final plane = image.planes.single;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
