import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import 'art_mode.dart';
import 'hero_art.dart';
import 'nemea_scene.dart';
import 'vector_style.dart';

/// Khung trang chủ dựng từ ảnh Blender chụp sẵn (test/art/art_bake_test.dart):
/// cảnh Thung lũng Nemea có sư tử (bản phủ bụi / đã giải phóng) và từng lớp
/// nhân vật tư thế đứng (da, áo, tóc, áo da). Da và tóc nhân màu lúc vẽ như
/// trong trận. Nhẹ hơn nạp atlas sprite 2048² chỉ để vẽ một khung tĩnh.
abstract final class HomeBannerArt {
  /// Hộp quanh chân nhân vật (đơn vị sân khấu) mà mỗi ảnh lớp phủ kín.
  static const heroBox = Rect.fromLTRB(28, -206, 100, 8);

  /// Điểm ảnh mỗi đơn vị sân khấu của ảnh chụp sẵn.
  static const pxPerUnit = 3.0;

  /// Chỗ chân nhân vật trên khung và tỉ lệ so với trong trận.
  static const heroAt = Offset(68, 218);
  static const heroScale = 0.82;

  /// Cảnh chụp sẵn: phông vẽ màn 1.8 + Sư tử Nemea đúng cỡ trong trận.
  /// [toon]: bản 2.5D (sư tử hoạt hình — atlas `nemea_lion_toon`).
  static String sceneAsset({required bool freed, bool toon = false}) =>
      'assets/banner/scene_${freed ? 'clear' : 'dust'}${toon ? '_toon' : ''}.webp';

  static String layerAsset(HeroSex sex, String layer) =>
      'assets/banner/hero_${sex.name}_$layer.webp';

  /// Các lớp nhân vật theo thứ tự vẽ (giống HeroSprites.paint).
  static List<String> layersFor(HeroLook look, {required bool cloak}) => [
    'skin',
    'cloth',
    'hair_${look.hairStyle.name}',
    if (cloak) 'pelt',
  ];

  static final _images = <String, ui.Image>{};
  static final _loading = <String, Future<void>>{};

  static List<String> _assets(
    HeroLook look, {
    required bool cloak,
    required bool freed,
  }) => [
    sceneAsset(freed: freed),
    for (final l in layersFor(look, cloak: cloak)) layerAsset(look.sex, l),
  ];

  static Future<void> load(
    HeroLook look, {
    required bool cloak,
    required bool freed,
  }) => Future.wait([
    for (final a in _assets(look, cloak: cloak, freed: freed))
      _loading[a] ??= _loadOne(a),
  ]);

  /// Nạp cảnh 2.5D (nhân vật vẽ vector đè lên, không cần lớp ảnh nhân vật).
  static Future<void> loadToonScene({required bool freed}) {
    final a = sceneAsset(freed: freed, toon: true);
    return _loading[a] ??= _loadOne(a);
  }

  /// Đã có cảnh 2.5D chụp sẵn (dùng khi ở chế độ 2.5D).
  static bool toonSceneReady({required bool freed}) =>
      !ArtModeSetting.blender &&
      _images.containsKey(sceneAsset(freed: freed, toon: true));

  /// Vẽ cảnh 2.5D chụp sẵn (gọi khi [toonSceneReady]).
  static void paintToonScene(Canvas canvas, {required bool freed}) {
    final scene = _images[sceneAsset(freed: freed, toon: true)]!;
    canvas.drawImageRect(
      scene,
      Rect.fromLTWH(0, 0, scene.width.toDouble(), scene.height.toDouble()),
      Offset.zero & stageSize,
      _paint..colorFilter = null,
    );
  }

  static Future<void> _loadOne(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      _images[asset] = (await codec.getNextFrame()).image;
    } catch (_) {
      // Chưa chụp ảnh này → khung vẽ bản vector.
    }
  }

  static bool ready(
    HeroLook look, {
    required bool cloak,
    required bool freed,
  }) =>
      ArtModeSetting.blender &&
      _assets(look, cloak: cloak, freed: freed).every(_images.containsKey);

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Vẽ cả khung theo toạ độ sân khấu (400×260). Gọi khi [ready].
  static void paint(
    Canvas canvas,
    HeroLook look, {
    required bool cloak,
    required bool freed,
  }) {
    final scene = _images[sceneAsset(freed: freed)]!;
    canvas.drawImageRect(
      scene,
      Rect.fromLTWH(0, 0, scene.width.toDouble(), scene.height.toDouble()),
      Offset.zero & stageSize,
      _paint..colorFilter = null,
    );
    canvas.save();
    canvas.translate(heroAt.dx, heroAt.dy);
    canvas.scale(heroScale * look.height);
    // Cảnh đã chụp kèm độ bão hoà sân khấu; nhân vật nhân màu lúc vẽ nên
    // tăng bão hoà ở đây cho cùng tông.
    canvas.saveLayer(
      heroBox,
      Paint()..colorFilter = saturationFilter(saturation),
    );
    for (final layer in layersFor(look, cloak: cloak)) {
      final img = _images[layerAsset(look.sex, layer)]!;
      final tint = layer == 'skin'
          ? look.skin
          : layer.startsWith('hair')
          ? look.hair
          : null;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        heroBox,
        _paint
          ..colorFilter = tint == null
              ? null
              : ColorFilter.mode(tint, BlendMode.modulate),
      );
    }
    canvas.restore();
    canvas.restore();
  }

  /// Độ bão hoà như sân khấu trận (BattleStageGame.saturation).
  static const saturation = 1.25;
}
