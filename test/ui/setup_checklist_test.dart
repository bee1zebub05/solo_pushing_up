import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/rep/setup_check.dart';
import 'package:solo_pushing_up/ui/setup_checklist.dart';

Future<void> pumpChecklist(WidgetTester tester, Set<SetupIssue> issues) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SetupChecklist(issues: issues)),
      ),
    );

int countIcon(WidgetTester tester, IconData icon) =>
    tester.widgetList<Icon>(find.byIcon(icon)).length;

void main() {
  testWidgets('đặt máy tốt: mọi dòng đều đạt', (tester) async {
    await pumpChecklist(tester, const {});

    expect(countIcon(tester, Icons.check_circle), 6);
    expect(find.textContaining('Mẹo: dựng điện thoại'), findsOneWidget);
  });

  testWidgets('chưa thấy người: các dòng phụ thuộc hiện "chưa rõ"', (
    tester,
  ) async {
    await pumpChecklist(tester, const {SetupIssue.noPerson});

    expect(countIcon(tester, Icons.cancel), 1);
    // Tay, mép, khoảng cách, góc máy chưa đánh giá được; ánh sáng vẫn đạt.
    expect(countIcon(tester, Icons.radio_button_unchecked), 4);
    expect(countIcon(tester, Icons.check_circle), 1);
    expect(find.textContaining('Chưa thấy người'), findsOneWidget);
  });

  testWidgets('máy chưa đặt trước mặt chỉ là nhắc nhẹ, không chặn', (
    tester,
  ) async {
    await pumpChecklist(tester, const {SetupIssue.notFacing});

    expect(countIcon(tester, Icons.error), 1);
    expect(countIcon(tester, Icons.cancel), 0);
    expect(
      find.text('Đặt máy trước mặt để vừa tập vừa xem màn hình'),
      findsOneWidget,
    );
  });

  testWidgets('thấy người nhưng không thấy tay', (tester) async {
    await pumpChecklist(tester, const {SetupIssue.armsNotVisible});

    expect(countIcon(tester, Icons.cancel), 1);
    expect(countIcon(tester, Icons.radio_button_unchecked), 3);
  });
}
