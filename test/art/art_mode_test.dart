import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solo_pushing_up/art/art_mode.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/art/home_banner_art.dart';
import 'package:solo_pushing_up/art/nemea_backdrop.dart';
import 'package:solo_pushing_up/art/nemea_map_art.dart';
import 'package:solo_pushing_up/art/sprite_atlas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ArtModeSetting.notifier.value = ArtMode.blender);

  test('mặc định 3D, đọc lại lựa chọn đã lưu', () async {
    await ArtModeSetting.load();
    expect(ArtModeSetting.mode, ArtMode.blender);
    await ArtModeSetting.set(ArtMode.vector);
    ArtModeSetting.notifier.value = ArtMode.blender;
    await ArtModeSetting.load();
    expect(ArtModeSetting.mode, ArtMode.vector);
  });

  testWidgets('2.5D giấu mọi tài nguyên Blender đã nạp', (tester) async {
    const look = HeroLook();
    await tester.runAsync(() async {
      await NemeaBackdrop.load();
      await NemeaMapImage.load();
      await SpriteAtlas.load('nemea_lion');
      await HomeBannerArt.load(look, cloak: false, freed: false);
    });
    bool anyBlender() =>
        NemeaBackdrop.ready ||
        SpriteAtlas.get('nemea_lion') != null ||
        HomeBannerArt.ready(look, cloak: false, freed: false);

    expect(anyBlender(), isTrue);
    ArtModeSetting.notifier.value = ArtMode.vector;
    expect(NemeaBackdrop.ready, isFalse);
    // Bản đồ là tranh vẽ (không phải Blender): giữ ở cả hai chế độ.
    expect(NemeaMapImage.image, isNotNull);
    expect(SpriteAtlas.get('nemea_lion'), isNull);
    expect(HomeBannerArt.ready(look, cloak: false, freed: false), isFalse);
    ArtModeSetting.notifier.value = ArtMode.blender;
    expect(anyBlender(), isTrue);
    NemeaBackdrop.evict();
    SpriteAtlas.evict('nemea_lion');
  });
}
