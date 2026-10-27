import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import 'art_mode.dart';

/// Một khung trong atlas: vùng ảnh trên trang [page] và vị trí góc trên trái
/// so với điểm neo, tính bằng đơn vị sân khấu.
class SpriteFrame {
  const SpriteFrame(this.page, this.src, this.offset, this.size);

  final int page;
  final Rect src;
  final Offset offset;
  final Size size;
}

/// Sprite dựng bằng Blender (tool/blender/sprite_kit.py): các trang WebP +
/// json mô tả khung theo chuỗi hoạt hình. Toạ độ đã tính sẵn theo đơn vị sân
/// khấu quanh điểm neo (chân quái hoặc tâm thân quái bay) — chỉ việc vẽ.
///
/// Nạp bất đồng bộ một lần cho mỗi tên ([SpriteAtlas.load]); khi chưa nạp
/// hình gọi vẫn vẽ bản vector như cũ.
class SpriteAtlas {
  SpriteAtlas._(this.pages, this.anims, this.meta);

  final List<ui.Image> pages;
  final Map<String, List<SpriteFrame>> anims;

  /// Thông số thêm trong json (chu kỳ idle…).
  final Map<String, dynamic> meta;

  static final _cache = <String, SpriteAtlas?>{};
  static final _loading = <String, Future<SpriteAtlas?>>{};

  /// Atlas có bản hoạt hình `<tên>_toon` (cùng mô hình, xương, biên đạo; tô
  /// màu phẳng + viền — tool/blender/toon_kit.py): chế độ 2.5D vẽ bản này
  /// thay hình vector cũ.
  static const toon = {
    'stymphalian_bird',
    'spartoi',
    'stone_soldier',
    'erymanthian_boar',
    'harpy',
    'young_hydra',
    'nemea_lion',
  };

  /// Tệp atlas thật cho [name] theo chế độ đồ hoạ; null = 2.5D vẽ vector.
  static String? _file(String name) => ArtModeSetting.blender
      ? name
      : toon.contains(name)
      ? '${name}_toon'
      : null;

  /// Atlas đã nạp ([load]), hoặc null — không tự nạp: chỉ trận đấu nạp
  /// (BossArt.preload), chân dung ở các màn hình khác vẽ bản vector.
  /// Chế độ 2.5D ([ArtMode.vector]): bản `_toon` nếu có ([toon]), còn lại null.
  static SpriteAtlas? get(String name) {
    final file = _file(name);
    return file == null ? null : _cache[file];
  }

  static Future<SpriteAtlas?> load(String name) {
    final file = _file(name);
    if (file == null) return Future.value();
    return _loadFile(file);
  }

  static Future<SpriteAtlas?> _loadFile(String name) {
    final pending = _loading[name];
    if (pending != null) return pending;
    late final Future<SpriteAtlas?> future;
    future = () async {
      SpriteAtlas? atlas;
      try {
        atlas = await _read(name);
      } catch (_) {
        // Thiếu tài nguyên (chưa render) → giữ bản vector.
        atlas = null;
      }
      // Bị [evict] trong lúc đang nạp (đã rời trận): bỏ luôn.
      if (!identical(_loading[name], future)) {
        atlas?._dispose();
        return null;
      }
      _cache[name] = atlas;
      return atlas;
    }();
    _loading[name] = future;
    return future;
  }

  /// Trả bộ nhớ ảnh khi rời trận (mỗi trang 2048² giải nén ~16 MB) — cả
  /// bản 3D lẫn bản `_toon` (chế độ có thể đã đổi giữa lúc nạp và lúc trả).
  static void evict(String name) {
    for (final file in [name, '${name}_toon']) {
      _loading.remove(file);
      _cache.remove(file)?._dispose();
    }
  }

  void _dispose() {
    for (final p in pages) {
      p.dispose();
    }
  }

  static Future<SpriteAtlas> _read(String name) async {
    final json = jsonDecode(
      await rootBundle.loadString('assets/sprites/$name.json'),
    ) as Map<String, dynamic>;
    final upp = (json['unitsPerPixel'] as num).toDouble();
    final pages = <ui.Image>[];
    for (var p = 0; p < (json['pages'] as int); p++) {
      final data = await rootBundle.load('assets/sprites/${name}_$p.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      pages.add((await codec.getNextFrame()).image);
    }
    final anims = <String, List<SpriteFrame>>{};
    (json['anims'] as Map<String, dynamic>).forEach((anim, list) {
      anims[anim] = [
        for (final f in list as List)
          SpriteFrame(
            f['p'] as int,
            Rect.fromLTWH(
              (f['x'] as num).toDouble(),
              (f['y'] as num).toDouble(),
              (f['w'] as num).toDouble(),
              (f['h'] as num).toDouble(),
            ),
            Offset((f['dx'] as num).toDouble(), (f['dy'] as num).toDouble()),
            Size((f['w'] as num) * upp, (f['h'] as num) * upp),
          ),
      ];
    });
    json.remove('anims');
    return SpriteAtlas._(pages, anims, json);
  }

  bool has(String anim) => anims[anim]?.isNotEmpty ?? false;

  double metaDouble(String key, double fallback) =>
      (meta[key] as num?)?.toDouble() ?? fallback;

  /// Tiến độ (0–1) của từng khung chuỗi [anim] khi khung không chia đều
  /// (`phases` trong json: dồn dày quanh cú đánh, thưa ở đoạn giữ thế —
  /// tool/blender/stone_tripo.py), hoặc null = chia đều.
  List<double>? phasesOf(String anim) {
    final all = meta['phases'] as Map<String, dynamic>?;
    final list = all?[anim] as List?;
    return list == null ? null : [for (final v in list) (v as num).toDouble()];
  }

  /// Vị trí (chỉ số khung, có phần lẻ) của tiến độ [t] trên dãy [phases].
  static double positionOf(List<double> phases, double t) {
    if (t <= phases.first) return 0;
    if (t >= phases.last) return phases.length - 1.0;
    var i = 0;
    while (phases[i + 1] < t) {
      i++;
    }
    return i + (t - phases[i]) / (phases[i + 1] - phases[i]);
  }

  /// Độ đậm (0–1) của dáng chờ vẽ đè lên đòn ở tiến độ [p]: đầu đòn tan
  /// dần từ dáng chờ, cuối đòn hiện dần lại — vòng đứng chờ đang ở pha bất
  /// kỳ nên chuyển thẳng sang khung đầu / khỏi khung cuối của đòn bị giật.
  static double idleBlend(double p, {double fade = 0.1}) {
    final w = p < fade
        ? 1 - p / fade
        : p > 1 - fade
        ? (p - (1 - fade)) / fade
        : 0.0;
    final c = w.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Vẽ chuỗi [anim] tại tiến độ [t] (0–1) quanh điểm neo (gốc canvas).
  /// [loop]: khung cuối nối về khung đầu. Hai khung kề nhau được hoà trộn
  /// theo phần lẻ để chuyển động mượt dù ít khung. [flash] 0–1: loé trắng
  /// khi trúng đòn. [tint]: nhân màu (lớp render trắng/xám trung tính, ví dụ
  /// da và tóc nhân vật theo màu người chơi chọn). [snap]: chỉ vẽ khung gần
  /// nhất — quanh cú ra đòn nhanh hai khung kề nhau cách xa, hoà thì hiện
  /// hai vũ khí chồng nhau.
  void draw(
    Canvas canvas,
    String anim,
    double t, {
    bool loop = false,
    double opacity = 1,
    double flash = 0,
    Color? tint,
    bool snap = false,
  }) {
    final frames = anims[anim];
    if (frames == null || frames.isEmpty) return;
    final n = frames.length;
    final phases = loop ? null : phasesOf(anim);
    final pos = loop
        ? (t % 1) * n
        : phases != null && phases.length == n
        ? positionOf(phases, t.clamp(0.0, 1.0))
        : t.clamp(0.0, 1.0) * (n - 1);
    if (snap) {
      _frame(canvas, frames[pos.round() % n], opacity, flash, tint);
      return;
    }
    final i = pos.floor() % n;
    final j = loop ? (i + 1) % n : (i + 1).clamp(0, n - 1);
    final mix = pos - pos.floor();
    _frame(canvas, frames[i], opacity, flash, tint);
    if (mix > 0.02 && j != i) {
      _frame(canvas, frames[j], opacity * mix, flash, tint);
    }
  }

  void _frame(
    Canvas canvas,
    SpriteFrame f,
    double opacity,
    double flash,
    Color? tint,
  ) {
    final paint = _paint
      ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
      ..colorFilter = flash > 0.01
          ? ColorFilter.mode(
              Color.fromRGBO(255, 244, 220, 0.6 * flash.clamp(0.0, 1.0)),
              BlendMode.srcATop,
            )
          : tint != null
          ? ColorFilter.mode(tint, BlendMode.modulate)
          : null;
    canvas.drawImageRect(pages[f.page], f.src, f.offset & f.size, paint);
  }
}
