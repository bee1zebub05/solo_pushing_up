import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/game/player_profile.dart';
import 'package:solo_pushing_up/game/profile_store.dart';
import 'package:solo_pushing_up/ui/character_creator_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<PlayerProfile?> open(WidgetTester tester) async {
    PlayerProfile? result;
    // Màn hình cao để cả danh sách được dựng, không cần cuộn.
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<PlayerProfile>(
                MaterialPageRoute(
                  builder: (_) => const CharacterCreatorScreen(),
                ),
              );
            },
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    // Khung xem trước chạy hoạt hình liên tục nên không pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return result;
  }

  testWidgets('chọn Nữ thì gợi ý đuôi ngựa, lưu được hồ sơ', (tester) async {
    PlayerProfile? saved;
    await open(tester);

    await tester.tap(find.text('Nữ'));
    await tester.pump();
    final ponytail = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Đuôi ngựa'),
    );
    expect(ponytail.selected, isTrue);

    await tester.enterText(find.byType(TextField), 'Lan');
    await tester.tap(find.text('Bắt đầu hành trình'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    saved = await ProfileStore.load();
    expect(saved?.name, 'Lan');
    expect(saved?.sex, HeroSex.female);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CharacterCreatorScreen), findsNothing);
  });

  testWidgets('tắt tự tính mỡ thì hiện thanh nhập tỉ lệ mỡ', (tester) async {
    await open(tester);
    expect(find.text('Tỉ lệ mỡ'), findsNothing);

    await tester.tap(find.text('Tự tính tỉ lệ mỡ'));
    await tester.pump();

    expect(find.text('Tỉ lệ mỡ'), findsOneWidget);
  });
}
