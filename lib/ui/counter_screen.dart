import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../dataset/mlkit_eval.dart';
import '../dataset/recording.dart';
import '../dataset/recording_store.dart';
import '../feedback/rep_feedback.dart';
import '../pose/pose_frame.dart';
import '../rep/pushup_counter.dart';
import '../rep/setup_check.dart';
import '../session/workout_session.dart';
import '../sim/pose_simulator.dart';
import 'label_dialog.dart';
import 'pill.dart';
import 'pose_source_view.dart';
import 'setup_checklist.dart';

/// Màn hình prototype: camera + khung xương + số rep + thông số debug
/// để tinh chỉnh ngưỡng của rep engine.
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen>
    with WidgetsBindingObserver {
  final WorkoutSession _session = WorkoutSession();
  String _lastEvent = '';

  /// Khác `null` khi đang ghi bản ghi để làm dữ liệu test.
  List<PoseFrame>? _recordingFrames;

  bool get _isRecording => _recordingFrames != null;
  PushupCounter get _counter => _session.counter;
  RepFeedback get _feedback => _session.feedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _session
      ..addListener(_onSessionChanged)
      ..frameListeners.add(_onFrame)
      ..init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  void _onFrame(PoseFrame frame, CounterSnapshot snapshot) {
    _recordingFrames?.add(frame);
    if (snapshot.events.isNotEmpty) {
      _lastEvent = _describeEvent(snapshot.events.last);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nguồn dữ liệu bị ngắt thì bản ghi đứt quãng, bỏ luôn.
    if (state == AppLifecycleState.inactive && _isRecording) {
      setState(() => _recordingFrames = null);
    }
    _session.handleLifecycle(state);
  }

  void _resetCounter({PushupMode? mode}) {
    _lastEvent = '';
    _session.resetCounter(mode: mode);
  }

  Future<void> _openSimulator() async {
    const backToCamera = 'camera';
    const evaluate = 'mlkit-eval';
    const evaluateAccurate = 'mlkit-eval-accurate';
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListView(
        children: [
          const ListTile(
            title: Text('Giả lập hít đất'),
            subtitle: Text('Người ảo tập theo kịch bản, thay cho camera'),
          ),
          if (_session.simMode)
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Quay lại camera'),
              onTap: () => Navigator.of(context).pop(backToCamera),
            ),
          for (final scenario in simScenarios)
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(scenario.name),
              subtitle: Text(scenario.expectation),
              onTap: () => Navigator.of(context).pop(scenario),
            ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Đánh giá ML Kit trên ảnh mẫu'),
            subtitle: const Text(
              'Cho ảnh tách từ video có nhãn (tool/push_eval.ps1) chạy qua '
              'ML Kit, lưu bản ghi để chấm điểm trên máy tính',
            ),
            onTap: () => Navigator.of(context).pop(evaluate),
          ),
          ListTile(
            leading: const Icon(Icons.science),
            title: const Text('Đánh giá ML Kit (model accurate)'),
            subtitle: const Text(
              'Như trên nhưng dùng model chính xác hơn/chậm hơn, '
              'lưu vào files/recordings_eval_accurate để so sánh',
            ),
            onTap: () => Navigator.of(context).pop(evaluateAccurate),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice is SimScenario) {
      // Đang ghi thì giữ nguyên số đếm của bản ghi.
      if (!_isRecording) _lastEvent = '';
      _session.playScenario(choice, keepCount: _isRecording);
    } else if (choice == backToCamera) {
      _lastEvent = '';
      _session.exitSimulator();
    } else if (choice == evaluate) {
      await _runMlKitEvaluation();
    } else if (choice == evaluateAccurate) {
      await _runMlKitEvaluation(accurate: true);
    }
  }

  Future<void> _runMlKitEvaluation({bool accurate = false}) async {
    _session.simulator.stop();
    _session.stopCamera();
    final progress = ValueNotifier<(String, double)>(('', 0));
    var cancelled = false;
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Đánh giá ML Kit'),
        content: ValueListenableBuilder(
          valueListenable: progress,
          builder: (context, value, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: value.$2),
              const SizedBox(height: 8),
              Text(value.$1.isEmpty ? 'Đang chuẩn bị…' : value.$1),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => cancelled = true,
            child: const Text('Dừng'),
          ),
        ],
      ),
    );
    var done = 0;
    String? failure;
    try {
      done = await MlKitDatasetEvaluator.run(
        onProgress: (clip, p) => progress.value = (clip, p),
        isCancelled: () => cancelled,
        accurate: accurate,
      );
    } on EvaluationAccessException {
      failure =
          'Android chặn đọc ảnh do adb đẩy vào. Dùng bản debug và '
          'tool/push_eval.ps1 -Internal.';
    } finally {
      if (mounted) Navigator.of(context).pop();
      progress.dispose();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure ??
              (done == 0
                  ? 'Không có ảnh mẫu. Chạy tool/push_eval.ps1 trước.'
                  : 'Xong $done clip → files/recordings_eval'
                        '${accurate ? '_accurate' : ''}'),
        ),
      ),
    );
    if (!_session.simMode && mounted) _session.startCamera();
  }

  Future<void> _toggleRecording() async {
    final frames = _recordingFrames;
    if (frames == null) {
      _recordingFrames = [];
      _resetCounter();
      return;
    }

    setState(() => _recordingFrames = null);
    final messenger = ScaffoldMessenger.of(context);
    if (frames.length < 2) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Bản ghi trống, không lưu')),
      );
      return;
    }

    final startMs = frames.first.timestampMs;
    final duration = Duration(milliseconds: frames.last.timestampMs - startMs);
    final labels = await showLabelDialog(
      context,
      counted: _counter.count,
      duration: duration,
    );
    if (labels == null) return;

    final simMode = _session.simMode;
    final recording = Recording(
      source: simMode
          ? 'simulator:${_session.simulator.scenario?.name ?? ''}'
          : 'mlkit-${Platform.operatingSystem}',
      createdAt: DateTime.now(),
      mode: _counter.mode,
      imageSize: frames.first.imageSize,
      expectedCount: labels.expectedCount,
      tags: {
        ...labels.tags,
        if (!simMode)
          'camera': _session.poseCamera.isFrontCamera ? 'trước' : 'sau',
      },
      notes: labels.notes,
      frames: [
        for (final f in frames)
          PoseFrame(
            timestampMs: f.timestampMs - startMs,
            landmarks: f.landmarks,
            imageSize: f.imageSize,
          ),
      ],
    );
    try {
      final file = await RecordingStore.save(recording);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã lưu ${file.uri.pathSegments.last}')),
      );
    } on FileSystemException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Lưu thất bại: ${e.message}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PoseSourceView(
                session: _session,
                onOpenSimulator: _openSimulator,
              ),
            ),
            Positioned(top: 8, left: 8, right: 8, child: _buildToolbar()),
            Positioned(top: 72, left: 0, right: 0, child: _buildCount()),
            Positioned(left: 8, right: 8, bottom: 8, child: _buildDebug()),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: SegmentedButton<PushupMode>(
            segments: const [
              ButtonSegment(
                value: PushupMode.knee,
                label: Text('Tân binh'),
                tooltip: 'Chống gối',
              ),
              ButtonSegment(
                value: PushupMode.standard,
                label: Text('Chiến binh'),
                tooltip: 'Push-up chuẩn',
              ),
            ],
            selected: {_counter.mode},
            onSelectionChanged: _isRecording
                ? null
                : (selection) => _resetCounter(mode: selection.single),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        IconButton.filled(
          tooltip: _isRecording ? 'Dừng ghi' : 'Ghi dữ liệu test',
          onPressed: _session.hasSource ? _toggleRecording : null,
          style: IconButton.styleFrom(
            backgroundColor: _isRecording ? Colors.red : Colors.black54,
          ),
          icon: Icon(
            _isRecording ? Icons.stop : Icons.fiber_manual_record,
            color: _isRecording ? Colors.white : Colors.redAccent,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Đếm lại',
          onPressed: _isRecording ? null : _resetCounter,
          icon: const Icon(Icons.restart_alt),
        ),
        IconButton.filledTonal(
          tooltip: 'Giả lập hít đất',
          onPressed: _openSimulator,
          isSelected: _session.simMode,
          icon: const Icon(Icons.smart_toy_outlined),
          selectedIcon: const Icon(Icons.smart_toy),
        ),
        if (_session.cameras.length > 1 && !_session.simMode)
          IconButton.filledTonal(
            tooltip: 'Đổi camera',
            onPressed: _isRecording ? null : _session.switchCamera,
            icon: const Icon(Icons.cameraswitch),
          ),
      ],
    );
  }

  String _recordingLabel() {
    final frames = _recordingFrames!;
    final ms = frames.length < 2
        ? 0
        : frames.last.timestampMs - frames.first.timestampMs;
    return 'REC ${(ms / 1000).toStringAsFixed(0)}s · ${frames.length} khung';
  }

  Widget _buildCount() {
    final snapshot = _session.snapshot;
    final setupIssues = _session.setupIssues;
    return Column(
      children: [
        Text(
          '${snapshot?.count ?? 0}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 96,
            fontWeight: FontWeight.w800,
            shadows: [Shadow(blurRadius: 12)],
          ),
        ),
        Pill(text: _hint(snapshot)),
        if (_isRecording) ...[
          const SizedBox(height: 8),
          Pill(text: _recordingLabel(), color: Colors.red.shade700),
        ],
        if (_lastEvent.isNotEmpty) ...[
          const SizedBox(height: 8),
          Pill(text: _lastEvent, color: Colors.amber.shade800),
        ],
        // Chỉ hiện lúc chuẩn bị, để không che màn hình khi đang tập.
        if (_session.frame != null &&
            (snapshot == null || snapshot.phase == CounterPhase.searching)) ...[
          const SizedBox(height: 12),
          SetupChecklist(
            issues: {
              ...setupIssues,
              // Đồng bộ với bộ đếm: bộ đếm không thấy tay thì bảng cũng báo vậy.
              if (snapshot?.trackingLost ?? false)
                setupIssues.contains(SetupIssue.noPerson)
                    ? SetupIssue.noPerson
                    : SetupIssue.armsNotVisible,
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDebug() {
    final s = _session.snapshot;
    String deg(double? v) => v == null ? '–' : '${v.toStringAsFixed(0)}°';
    final thresholds = s == null
        ? '–'
        : '${deg(s.topThreshold)}/${deg(s.bottomThreshold)}'
              '${s.calibrated ? ' (tự chỉnh)' : ''}';
    final mlMs = _session.frame?.processingMs;
    final lines = [
      '${s?.phase.name ?? '–'} · ${_session.fps.toStringAsFixed(0)} FPS'
          '${mlMs == null ? '' : ' · ML ${mlMs}ms'}',
      'Khuỷu ${deg(s?.elbowAngle)} · Thân ${deg(s?.bodyAngle)}'
          ' · ${_postureLabel(s?.posture)}',
      'Ngưỡng $thresholds',
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lines.join('\n'),
                style: const TextStyle(
                  color: Colors.white70,
                  // iOS không có font tên 'monospace': dùng chữ số đều
                  // độ rộng của font hệ thống để các cột số thẳng hàng.
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontSize: 12,
                ),
              ),
            ),
            SoundModeButton(feedback: _feedback, onChanged: _onSessionChanged),
            IconButton(
              tooltip: _feedback.vibrationOn ? 'Tắt rung' : 'Bật rung',
              onPressed: () => setState(
                () => _feedback.vibrationOn = !_feedback.vibrationOn,
              ),
              icon: Icon(
                _feedback.vibrationOn ? Icons.vibration : Icons.mobile_off,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _hint(CounterSnapshot? s) {
    if (s == null) return 'Dựng máy trước mặt, thấy rõ đầu, vai và hai tay';
    if (s.phase == CounterPhase.searching) {
      // Bảng kiểm tra đã nói chi tiết từng lỗi, ở đây chỉ dẫn bước tiếp theo.
      return _session.setupIssues.any((issue) => issue.blocking)
          ? 'Chỉnh máy theo bảng bên dưới'
          : 'Vào tư thế chống đẩy, duỗi thẳng tay';
    }
    if (s.trackingLost) return 'Không thấy rõ tay — lùi xa hoặc xoay máy';
    return switch (s.phase) {
      CounterPhase.searching => 'Vào tư thế chống đẩy, duỗi thẳng tay',
      CounterPhase.top =>
        s.holdMs >= 1000
            ? 'Giữ ${(s.holdMs / 1000).toStringAsFixed(1)}s'
            : 'Sẵn sàng',
      CounterPhase.goingDown => 'Xuống…',
      CounterPhase.bottom => 'Đẩy lên!',
    };
  }

  String _describeEvent(RepEvent event) => switch (event) {
    CountedRep() => [
      '+1',
      if (event.isDeep) 'SÂU',
      if (event.isFast) 'NHANH',
      if (event.isSlow) 'CHẬM',
      '${(event.durationMs / 1000).toStringAsFixed(1)}s',
      if (event.formWarning) 'giữ thân thẳng hơn',
    ].join(' · '),
    PartialRep() => 'Chưa đủ sâu! (${event.minElbowAngle.toStringAsFixed(0)}°)',
    RejectedRep(reason: RejectReason.kneelingInStandardMode) =>
      'Chế độ Chiến binh: hãy duỗi thẳng chân',
    RejectedRep(reason: RejectReason.bodyNotStraight) => 'Giữ thân thẳng!',
  };

  String _postureLabel(Posture? posture) => switch (posture) {
    Posture.knee => 'chống gối',
    Posture.standard => 'chuẩn',
    Posture.unknown || null => 'không rõ',
  };
}

/// Nút đổi vòng chế độ âm báo: giọng đọc → bíp → tắt.
class SoundModeButton extends StatelessWidget {
  const SoundModeButton({
    super.key,
    required this.feedback,
    required this.onChanged,
  });

  final RepFeedback feedback;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: switch (feedback.soundMode) {
        SoundMode.voice => 'Đang đọc số rep — bấm để chỉ bíp',
        SoundMode.beep => 'Đang bíp — bấm để tắt âm',
        SoundMode.off => 'Đang tắt âm — bấm để đọc số rep',
      },
      onPressed: () {
        feedback.soundMode = SoundMode
            .values[(feedback.soundMode.index + 1) % SoundMode.values.length];
        onChanged();
      },
      icon: Icon(switch (feedback.soundMode) {
        SoundMode.voice => Icons.record_voice_over,
        SoundMode.beep => Icons.volume_up,
        SoundMode.off => Icons.volume_off,
      }, color: Colors.white70),
    );
  }
}
