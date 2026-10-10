import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/ui/label_dialog.dart';

void main() {
  Future<RecordingLabels?> openDialog(
    WidgetTester tester,
    Future<void> Function() interact,
  ) async {
    RecordingLabels? result;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showLabelDialog(
                context,
                counted: 12,
                duration: const Duration(seconds: 30),
              );
              closed = true;
            },
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await interact();
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    return result;
  }

  testWidgets('điền sẵn số app đếm, lưu kèm điều kiện quay', (tester) async {
    final labels = await openDialog(tester, () async {
      expect(find.text('App đếm 12 rep trong 30.0s.'), findsOneWidget);
      await tester.tap(find.text('chéo'));
      await tester.tap(find.text('tối'));
      await tester.pump();
      await tester.tap(find.text('Lưu'));
    });

    expect(labels!.expectedCount, 12);
    expect(labels.tags, {'angle': 'chéo', 'light': 'tối'});
  });

  testWidgets('sửa số rep thật', (tester) async {
    final labels = await openDialog(tester, () async {
      await tester.enterText(find.byType(TextField).first, '15');
      await tester.pump();
      await tester.tap(find.text('Lưu'));
    });

    expect(labels!.expectedCount, 15);
  });

  testWidgets('ô số rep trống thì không lưu được; Bỏ trả về null', (
    tester,
  ) async {
    final labels = await openDialog(tester, () async {
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu'),
      );
      expect(save.onPressed, isNull);
      await tester.tap(find.text('Bỏ'));
    });

    expect(labels, isNull);
  });
}
