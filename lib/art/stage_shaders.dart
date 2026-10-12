import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Hiệu ứng sân khấu chạy bằng fragment shader (GPU). Mỗi shader vẽ vào một
/// ảnh nhỏ cố định rồi phóng lên sân khấu: toạ độ trong shader không phụ
/// thuộc camera/lớp màu, và GPU chỉ tô ~26 nghìn điểm ảnh thay vì cả màn hình
/// (nút cổ chai trên máy tầm trung là raster, rules/dohoa.md mục 6).
///
/// Shader chưa nạp xong (hoặc nền tảng không hỗ trợ) thì bỏ qua hiệu ứng,
/// sân khấu vẫn chạy bình thường.
class StagnationMist {
  StagnationMist({this.width = 200, this.height = 130});

  final int width;
  final int height;

  static ui.FragmentProgram? _program;
  static bool _failed = false;

  /// Nạp shader một lần cho cả app (gọi lúc vào trận). Đã nạp (hoặc đã hỏng)
  /// thì trả về ngay, không chờ lại Future cũ của lần vào trận trước.
  static Future<void> load() async {
    if (_program != null || _failed) return;
    try {
      _program = await ui.FragmentProgram.fromAsset(
        'shaders/stagnation_mist.frag',
      );
    } catch (_) {
      _failed = true;
    }
  }

  ui.FragmentShader? _shader;
  ui.Image? _image;
  double _since = 1;

  /// Cập nhật ảnh sương ~30 lần/giây (sương trôi chậm, đủ mượt).
  void update(
    double dt, {
    required double time,
    required double density,
    required Color color,
  }) {
    final program = _program;
    if (program == null) return;
    _since += dt;
    if (_since < 1 / 30 && _image != null) return;
    _since = 0;
    final shader = _shader ??= program.fragmentShader();
    shader
      ..setFloat(0, width.toDouble())
      ..setFloat(1, height.toDouble())
      ..setFloat(2, time)
      ..setFloat(3, density.clamp(0.0, 1.0))
      ..setFloat(4, color.r)
      ..setFloat(5, color.g)
      ..setFloat(6, color.b)
      ..setFloat(7, color.a);
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..shader = shader,
    );
    final picture = recorder.endRecording();
    _image?.dispose();
    _image = picture.toImageSync(width, height);
    picture.dispose();
  }

  /// Vẽ sương phủ [rect] (toạ độ sân khấu), lọc mượt khi phóng to.
  void paint(Canvas canvas, Rect rect) {
    final image = _image;
    if (image == null) return;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.low,
    );
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _shader?.dispose();
    _shader = null;
  }
}
