import 'dart:ui';

import 'budget.dart';

/// Một lớp tĩnh chụp sẵn thành ảnh ở lần vẽ đầu; các khung sau chỉ vẽ ảnh.
///
/// - [bounds]: vùng (toạ độ sân khấu) được chụp — chừa lề cho parallax.
/// - [resolution]: bội số so với độ phân giải chung. Vật bị phóng to khi vẽ
///   thì > 1; lớp xa (trời, núi) có thể < 1 — mềm đi một chút hợp với phối
///   cảnh không khí và tiết kiệm bộ nhớ.
/// - Ảnh tự chụp lại khi độ phân giải chung đổi > 15 % (xoay máy), và có
///   thể bị [RasterBudget] giải phóng khi thiếu bộ nhớ — lần vẽ sau chụp lại.
class RasterLayer {
  RasterLayer(
    this.draw, {
    this.bounds = const Rect.fromLTRB(-20, -20, 420, 280),
    this.resolution = 1,
    RasterBudget? budget,
  }) : _budget = budget;

  final void Function(Canvas canvas) draw;
  final Rect bounds;
  final double resolution;
  final RasterBudget? _budget;

  RasterBudget get budget => _budget ?? RasterBudget.shared;

  Image? _image;
  double _scale = 0;

  /// Thời điểm (ms, theo đồng hồ của ngân sách) lần cuối được vẽ.
  int lastPaintMs = 0;

  /// Số lần đã chụp ảnh (để test / đo).
  int renders = 0;

  static final _paint = Paint()..filterQuality = FilterQuality.low;

  bool get hasImage => _image != null;

  /// Byte ảnh đang giữ (RGBA 4 byte/điểm).
  int get bytes {
    final image = _image;
    return image == null ? 0 : image.width * image.height * 4;
  }

  /// Vẽ ảnh vào đúng [bounds]. [opacity] < 1 trộn bằng alpha của Paint
  /// (không cần saveLayer); [colorFilter] đổi tông cùng một ảnh (ví dụ bản
  /// "phủ bụi" mất màu) thay vì giữ thêm một ảnh thứ hai.
  void paint(Canvas canvas, {double opacity = 1, ColorFilter? colorFilter}) {
    final b = budget;
    final s = b.effectiveScale;
    if (_image != null && (s - _scale).abs() > _scale * 0.15) dispose();
    lastPaintMs = b.now();
    final image = _image ?? _render(b);
    final paint = opacity >= 1 && colorFilter == null
        ? _paint
        : (Paint()
            ..filterQuality = FilterQuality.low
            ..colorFilter = colorFilter
            ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      bounds,
      paint,
    );
  }

  /// Kích thước ảnh (điểm ảnh) nếu chụp ở độ phân giải chung hiện tại.
  (int, int) pixelSize([double? scale]) {
    final k = (scale ?? budget.effectiveScale) * resolution;
    return ((bounds.width * k).ceil(), (bounds.height * k).ceil());
  }

  Image _render(RasterBudget b) {
    _scale = b.effectiveScale;
    final k = _scale * resolution;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(k)
      ..translate(-bounds.left, -bounds.top);
    draw(canvas);
    final picture = recorder.endRecording();
    final (w, h) = pixelSize(_scale);
    final image = picture.toImageSync(w, h);
    picture.dispose();
    _image = image;
    renders++;
    b.admit(this);
    return image;
  }

  void dispose() {
    _image?.dispose();
    _image = null;
    budget.release(this);
  }
}
