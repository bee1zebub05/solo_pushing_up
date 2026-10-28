import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import 'art_mode.dart';
import 'nemea_scene.dart';

/// Phông Thung lũng Nemea dựng bằng Blender (tool/blender/scenes/nemea_valley.py):
/// mỗi tầng chiều sâu ([NemeaLayer]) và tiền cảnh là một ảnh WebP phủ cả sân
/// khấu, rộng thêm [margin] đơn vị mỗi bên cho camera trôi. Chỉ nạp khi vào
/// trận (BossArt.preload) và trả bộ nhớ khi rời trận; chưa nạp xong thì sân
/// khấu vẽ bản vector (nemea_scene.dart).
abstract final class NemeaBackdrop {
  static const margin = 24.0;

  static final _dest = Rect.fromLTWH(
    -margin,
    0,
    stageSize.width + 2 * margin,
    stageSize.height,
  );

  static final _images = <String, ui.Image>{};
  static Future<void>? _loading;
  static int _generation = 0;

  static String _file(String name) => 'assets/backdrops/nemea_$name.webp';

  static const _names = ['sky', 'far', 'mid', 'near', 'fg'];

  /// Chế độ 2.5D ([ArtMode.vector]) luôn false → sân khấu vẽ bản vector.
  static bool get ready =>
      ArtModeSetting.blender && _images.length == _names.length;

  static Future<void> load() => _loading ??= _load(_generation);

  static Future<void> _load(int generation) async {
    final loaded = <String, ui.Image>{};
    try {
      for (final name in _names) {
        final data = await rootBundle.load(_file(name));
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        loaded[name] = (await codec.getNextFrame()).image;
      }
    } catch (_) {
      // Thiếu tài nguyên (chưa render) → giữ bản vector.
      for (final img in loaded.values) {
        img.dispose();
      }
      return;
    }
    // Bị [evict] trong lúc đang nạp (đã rời trận): bỏ luôn.
    if (generation != _generation) {
      for (final img in loaded.values) {
        img.dispose();
      }
      return;
    }
    _images.addAll(loaded);
  }

  /// Trả bộ nhớ ảnh khi rời trận.
  static void evict() {
    _generation++;
    _loading = null;
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
  }

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  static void _draw(Canvas canvas, String name, ColorFilter? filter) {
    final img = _images[name];
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      _dest,
      _paint..colorFilter = filter,
    );
  }

  /// Một tầng chiều sâu, qua bộ lọc bụi [filter] nếu có.
  static void paintLayer(
    Canvas canvas,
    NemeaLayer layer, {
    ColorFilter? filter,
  }) => _draw(canvas, layer.name, filter);

  /// Tiền cảnh (cỏ, đá tối ở hai góc dưới) đè lên nhân vật.
  static void paintForeground(Canvas canvas, {ColorFilter? filter}) =>
      _draw(canvas, 'fg', filter);
}

/// Phông vẽ riêng từng màn chương 1 (art_src/backdrop_prompts/1.X.png →
/// tool/import_painted_backdrops.py → `assets/backdrops/nemea_stage_<màn>.webp`),
/// mỗi màn đúng cảnh ở điểm màn đó trên bản đồ (rừng ô liu, ruộng ven sông,
/// đồi đền, bụi rậm, cầu, đầm, vách đá, hang). Một ảnh phủ cả sân khấu rộng
/// thêm [NemeaBackdrop.margin] mỗi bên; dùng ở cả 2.5D lẫn 3D (tranh vẽ, không
/// phải tài nguyên Blender). Mỗi lúc chỉ giữ ảnh của một màn.
abstract final class NemeaStageBackdrop {
  static ui.Image? _image;
  static String? _scene;
  static Future<void>? _loading;
  static int _generation = 0;

  /// Đã nạp ảnh của màn đang chơi.
  static bool get ready => _image != null;

  /// Nạp phông màn [scene] (ví dụ `1_5`); màn khác đang giữ thì trả trước.
  static Future<void> load(String scene) {
    if (_scene != scene) evict();
    _scene = scene;
    return _loading ??= _load(scene, _generation);
  }

  static Future<void> _load(String scene, int generation) async {
    ui.Image? img;
    try {
      final data = await rootBundle.load(
        'assets/backdrops/nemea_stage_$scene.webp',
      );
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      img = (await codec.getNextFrame()).image;
    } catch (_) {
      return; // thiếu ảnh → sân khấu vẽ phông cũ
    }
    if (generation != _generation) {
      img.dispose();
      return;
    }
    _image = img;
  }

  static void evict() {
    _generation++;
    _loading = null;
    _scene = null;
    _image?.dispose();
    _image = null;
  }

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Vẽ phông (qua bộ lọc bụi [filter] nếu có).
  static void paint(Canvas canvas, {ColorFilter? filter}) {
    final img = _image;
    if (img == null) return;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      NemeaBackdrop._dest,
      _paint..colorFilter = filter,
    );
  }
}
