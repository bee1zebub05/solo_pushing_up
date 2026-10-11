import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/game/labors.dart';
import 'package:solo_pushing_up/game/progress.dart';
import 'package:solo_pushing_up/ui/stage_select_screen.dart';

void main() {
  final nemea = labors.firstWhere((l) => l.id == 'nemea');

  testWidgets(
    'danh sách 10 màn: màn đầu mở, màn sau khoá; chạm màn mở thì chơi',
    (tester) async {
      Stage? played;
      await tester.pumpWidget(
        MaterialApp(
          home: StageSelectScreen(
            labor: nemea,
            progress: PlayerProgress(completedStages: {'nemea_1_1'}),
            onPlay: (s) async => played = s,
          ),
        ),
      );
      expect(find.textContaining('1.1  '), findsOneWidget);
      expect(find.text('2/10 màn'), findsNothing);
      expect(find.text('1/10 màn'), findsOneWidget);

      // 1.2 đã mở (thắng 1.1), 1.3 còn khoá.
      await tester.tap(find.textContaining('1.2  '));
      expect(played?.code, '1.2');
      played = null;
      await tester.tap(find.textContaining('1.3  '), warnIfMissed: false);
      expect(played, isNull);
    },
  );
}
