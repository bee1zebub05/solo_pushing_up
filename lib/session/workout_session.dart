import 'package:app_settings/app_settings.dart';
import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import '../feedback/rep_feedback.dart';
import '../pose/pose_camera.dart';
import '../pose/pose_frame.dart';
import '../rep/pushup_counter.dart';
import '../rep/setup_check.dart';
import '../sim/pose_simulator.dart';

typedef FrameListener = void Function(
  PoseFrame frame,
  CounterSnapshot snapshot,
);

/// Một phiên tập: nguồn tư thế (camera hoặc người ảo) → bộ đếm → âm báo,
/// cùng quyền camera và vòng đời app. Dùng chung cho màn hình đếm (debug)
/// và màn hình chiến đấu.
class WorkoutSession extends ChangeNotifier {
  WorkoutSession({PushupMode mode = PushupMode.standard})
    : counter = PushupCounter(mode: mode);

  final PushupCounter counter;
  final RepFeedback feedback = RepFeedback();
  final SetupChecker _setupChecker = SetupChecker();
  late final PoseCamera poseCamera = PoseCamera(onFrame: _onFrame);
  late final PoseSimulator simulator = PoseSimulator(
    onFrame: _onFrame,
    onDone: notifyListeners,
  );

  /// Được gọi với mỗi khung đã xử lý (để ghi bản ghi, áp vào trận đấu…).
  final List<FrameListener> frameListeners = [];

  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;

  /// Tăng mỗi lần bật/tắt camera, để bỏ kết quả của lần khởi động đã lỗi thời.
  int _cameraGeneration = 0;

  /// Đang khởi động camera, có thể đang chờ hộp thoại xin quyền.
  bool _starting = false;

  /// Người dùng vừa bấm "Mở Cài đặt": khi quay lại app thì thử mở camera.
  bool _awaitingSettings = false;

  bool _disposed = false;

  String? error;

  /// Người dùng đã từ chối quyền camera: hiện nút mở Cài đặt.
  bool permissionDenied = false;

  /// Đang dùng người ảo thay cho camera.
  bool simMode = false;

  PoseFrame? frame;
  CounterSnapshot? snapshot;
  Set<SetupIssue> setupIssues = const {};
  double fps = 0;
  int? _lastFrameMs;

  List<CameraDescription> get cameras => _cameras;

  /// Camera đã sẵn sàng hoặc đang dùng giả lập (có nguồn tư thế).
  bool get hasSource =>
      simMode || (poseCamera.controller?.value.isInitialized ?? false);

  Future<void> init() async {
    await feedback.init();
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      error = 'Không mở được camera: ${e.description}';
      notifyListeners();
      return;
    }
    if (_cameras.isEmpty) {
      error = 'Không tìm thấy camera';
      notifyListeners();
      return;
    }
    final front = _cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    _cameraIndex = front >= 0 ? front : 0;
    await startCamera();
  }

  @override
  void dispose() {
    _disposed = true;
    simulator.stop();
    poseCamera.dispose();
    feedback.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  /// Reset số đếm và mọi trạng thái đi kèm (âm báo, kiểm tra đặt máy).
  void resetCounter({PushupMode? mode}) {
    counter.reset(mode: mode);
    feedback.reset();
    _setupChecker.reset();
    setupIssues = const {};
    snapshot = null;
    notifyListeners();
  }

  /// Gọi từ `didChangeAppLifecycleState` của màn hình đang dùng phiên này.
  void handleLifecycle(AppLifecycleState state) {
    // Hộp thoại xin quyền camera làm app inactive rồi resumed. Nếu tắt/mở lại
    // camera lúc này, kết quả "Từ chối" bị bỏ qua và hộp thoại hiện lại mãi.
    if (_starting) return;
    // Đã bị từ chối quyền: không tự xin lại (hộp thoại sẽ hiện lặp lại),
    // trừ khi người dùng vừa sang Cài đặt và có thể đã bật quyền.
    if (permissionDenied) {
      if (state == AppLifecycleState.resumed && _awaitingSettings) {
        _awaitingSettings = false;
        startCamera();
      }
      return;
    }
    if (state == AppLifecycleState.inactive) {
      if (simMode) {
        simulator.stop();
      } else {
        stopCamera();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!simMode && _cameras.isNotEmpty) startCamera();
    }
  }

  Future<void> retry() => _cameras.isEmpty ? init() : startCamera();

  void openSettings() {
    _awaitingSettings = true;
    AppSettings.openAppSettings();
  }

  Future<void> startCamera() async {
    final generation = ++_cameraGeneration;
    _starting = true;
    try {
      await poseCamera.start(_cameras[_cameraIndex]);
    } on CameraException catch (e) {
      if (generation != _cameraGeneration || _disposed) return;
      // CameraAccessDenied, CameraAccessDeniedWithoutPrompt, CameraAccessRestricted…
      permissionDenied = e.code.startsWith('CameraAccess');
      error = permissionDenied
          ? 'Cần quyền camera để đếm push-up.\n'
                'Video chỉ xử lý trên máy, không gửi đi đâu.'
          : 'Lỗi camera: ${e.description}';
      notifyListeners();
      return;
    } finally {
      if (generation == _cameraGeneration) _starting = false;
    }
    // Lần khởi động này đã bị thay bởi lần bật/tắt camera mới hơn.
    if (generation != _cameraGeneration || _disposed) return;
    permissionDenied = false;
    error = null;
    frame = null;
    resetCounter(mode: counter.mode);
  }

  void stopCamera() {
    _cameraGeneration++;
    _starting = false;
    poseCamera.stop();
  }

  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await startCamera();
  }

  /// Phát một kịch bản người ảo thay cho camera. [keepCount]: giữ số đếm
  /// (ví dụ đang ghi bản ghi).
  void playScenario(SimScenario scenario, {bool keepCount = false}) {
    if (!simMode) stopCamera();
    simMode = true;
    error = null;
    frame = null;
    if (!keepCount) resetCounter();
    simulator.play(scenario);
    notifyListeners();
  }

  void exitSimulator() {
    simulator.stop();
    simMode = false;
    frame = null;
    resetCounter();
    startCamera();
  }

  void _onFrame(PoseFrame newFrame) {
    if (_disposed) return;
    final newSnapshot = counter.update(newFrame);
    feedback.onSnapshot(newSnapshot);
    setupIssues = _setupChecker.update(newFrame);
    final lastFrameMs = _lastFrameMs;
    if (lastFrameMs != null && newFrame.timestampMs > lastFrameMs) {
      final instant = 1000 / (newFrame.timestampMs - lastFrameMs);
      fps = fps == 0 ? instant : fps * 0.9 + instant * 0.1;
    }
    _lastFrameMs = newFrame.timestampMs;
    frame = newFrame;
    snapshot = newSnapshot;
    for (final listener in List.of(frameListeners)) {
      listener(newFrame, newSnapshot);
    }
    notifyListeners();
  }
}
