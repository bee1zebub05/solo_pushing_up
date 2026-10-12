import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Hiệu ứng sân khấu chạy bằng fragment shader (GPU). Mỗi shader vẽ vào một
/// ảnh nhỏ cố định rồi phóng lên sân khấu: toạ độ trong shader không phụ
/// thuộc camera/lớp màu, và GPU chỉ tô vài chục nghìn điểm ảnh thay vì cả màn
/// hình (nút cổ chai trên máy tầm trung là raster, rules/dohoa.md mục 6).
///
/// Shader chưa nạp (hoặc nền tảng không hỗ trợ) thì [ShaderLayer.ready] là
/// `false`: nơi gọi vẽ bản vector cũ hoặc bỏ qua, sân khấu vẫn chạy.
abstract final class StageShaders {
  static const mist = 'shaders/stagnation_mist.frag';
  static const aurora = 'shaders/aurora.frag';
  static const caustics = 'shaders/caustics.frag';

  static final _programs = <String, ui.FragmentProgram>{};
  static final _failed = <String>{};

  /// Nạp mọi shader một lần cho cả app (gọi lúc vào trận). Đã nạp (hoặc đã
  /// hỏng) thì bỏ qua, không chờ lại Future cũ của lần vào trận trước.
  static Future<void> load() async {
    for (final asset in const [mist, aurora, caustics]) {
      if (_programs.containsKey(asset) || _failed.contains(asset)) continue;
      try {
        _programs[asset] = await ui.FragmentProgram.fromAsset(asset);
      } catch (_) {
        _failed.add(asset);
      }
    }
  }
}

/// Một lớp shader: ảnh [width]×[height] vẽ lại ~30 lần/giây.
///
/// Thứ tự uniform trong mọi shader sân khấu: `uSize` (vec2), `uTime`, rồi các
/// uniform riêng do [paint] truyền vào qua `uniforms` (bắt đầu từ chỉ số 3).
class ShaderLayer {
  ShaderLayer(this.asset, {required this.width, required this.height});

  final String asset;
  final int width;
  final int height;

  ui.FragmentShader? _shader;
  ui.Image? _image;
  double _drawnAt = double.negativeInfinity;

  bool get ready => StageShaders._programs.containsKey(asset);

  /// Vẽ lớp phủ [rect] (toạ độ sân khấu). Ảnh chỉ vẽ lại khi đã qua 1/30
  /// giây kể từ lần trước (hiệu ứng trôi chậm, đủ mượt).
  void paint(
    Canvas canvas,
    Rect rect, {
    required double time,
    void Function(ui.FragmentShader shader)? uniforms,
    BlendMode blendMode = BlendMode.srcOver,
  }) {
    final program = StageShaders._programs[asset];
    if (program == null) return;
    if (_image == null || (time - _drawnAt).abs() >= 1 / 30) {
      _drawnAt = time;
      final shader = _shader ??= program.fragmentShader();
      shader
        ..setFloat(0, width.toDouble())
        ..setFloat(1, height.toDouble())
        ..setFloat(2, time);
      uniforms?.call(shader);
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
    canvas.drawImageRect(
      _image!,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      rect,
      Paint()
        ..filterQuality = FilterQuality.low
        ..blendMode = blendMode,
    );
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    _shader?.dispose();
    _shader = null;
  }
}

/// Đặt màu vào 4 uniform liên tiếp từ [index] (rgb + a).
void setColorUniform(ui.FragmentShader shader, int index, Color color) {
  shader
    ..setFloat(index, color.r)
    ..setFloat(index + 1, color.g)
    ..setFloat(index + 2, color.b)
    ..setFloat(index + 3, color.a);
}
