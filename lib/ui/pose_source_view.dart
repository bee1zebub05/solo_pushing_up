import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../session/workout_session.dart';
import '../sim/synthetic_pushup.dart';
import 'skeleton_painter.dart';

/// Khung hiển thị nguồn tư thế của một [WorkoutSession]: camera kèm khung
/// xương, người ảo (giả lập), hoặc màn hình lỗi quyền camera.
class PoseSourceView extends StatelessWidget {
  const PoseSourceView({
    super.key,
    required this.session,
    required this.onOpenSimulator,
  });

  final WorkoutSession session;
  final VoidCallback onOpenSimulator;

  @override
  Widget build(BuildContext context) {
    if (session.simMode) return _simulator();
    final error = session.error;
    if (error != null) return _error(error);

    final controller = session.poseCamera.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Stack(
        children: [
          CameraPreview(controller),
          Positioned.fill(
            child: CustomPaint(
              painter: SkeletonPainter(
                frame: session.frame,
                mirror: session.poseCamera.overlayNeedsMirror,
                minConfidence: session.counter.config.minConfidence,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _simulator() {
    final simulator = session.simulator;
    final scenario = simulator.scenario;
    final status = simulator.isPlaying
        ? 'Đang chạy ${(simulator.progress * 100).round()}%'
        : 'Đã xong — bấm 🤖 để chạy kịch bản khác';
    return Center(
      child: AspectRatio(
        aspectRatio: syntheticImageSize.width / syntheticImageSize.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900,
            border: Border.all(color: Colors.white24),
          ),
          child: CustomPaint(
            painter: SkeletonPainter(
              frame: session.frame,
              mirror: false,
              minConfidence: session.counter.config.minConfidence,
            ),
            child: Align(
              // Góc dưới: phía trên bị nhãn sự kiện rep che.
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'GIẢ LẬP · ${scenario?.name ?? ''}\n'
                  'Mong đợi: ${scenario?.expectation ?? ''}\n'
                  '$status',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _error(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (session.permissionDenied)
                  FilledButton.icon(
                    // Quay lại app thì phiên tự mở lại camera.
                    onPressed: session.openSettings,
                    icon: const Icon(Icons.settings),
                    label: const Text('Mở Cài đặt'),
                  ),
                OutlinedButton.icon(
                  onPressed: session.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenSimulator,
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: const Text('Dùng giả lập'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
