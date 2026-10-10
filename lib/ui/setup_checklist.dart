import 'package:flutter/material.dart';

import '../rep/setup_check.dart';

String setupAdvice(SetupIssue issue) => switch (issue) {
  SetupIssue.noPerson => 'Chưa thấy người — lùi ra để cả người vào khung',
  SetupIssue.armsNotVisible => 'Chưa thấy rõ vai, khuỷu tay, cổ tay',
  SetupIssue.cutOffEdge => 'Tay sát mép khung — lùi xa hoặc chỉnh máy',
  SetupIssue.tooClose => 'Quá gần — lùi ra xa máy một chút',
  SetupIssue.tooFar => 'Hơi xa — lại gần máy hơn',
  SetupIssue.notFacing => 'Đặt máy trước mặt để vừa tập vừa xem màn hình',
  SetupIssue.tooDark => 'Hơi tối — bật thêm đèn',
};

/// Bảng kiểm tra đặt máy, hiện lúc chuẩn bị tập.
class SetupChecklist extends StatelessWidget {
  const SetupChecklist({super.key, required this.issues});

  final Set<SetupIssue> issues;

  @override
  Widget build(BuildContext context) {
    final noPerson = issues.contains(SetupIssue.noPerson);
    // Chưa thấy tay thì chưa đánh giá được mép, khoảng cách, góc máy.
    final noArms = noPerson || issues.contains(SetupIssue.armsNotVisible);
    final rows = [
      ('Thấy người trong khung', {SetupIssue.noPerson}, false),
      ('Thấy rõ vai, khuỷu tay, cổ tay', {SetupIssue.armsNotVisible}, noPerson),
      ('Không sát mép khung', {SetupIssue.cutOffEdge}, noArms),
      (
        'Khoảng cách vừa phải',
        {SetupIssue.tooClose, SetupIssue.tooFar},
        noArms,
      ),
      ('Máy đặt trước mặt', {SetupIssue.notFacing}, noArms),
      ('Đủ ánh sáng', {SetupIssue.tooDark}, false),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, related, unknown) in rows)
            _ChecklistRow(
              label: switch (issues.intersection(related).firstOrNull) {
                final issue? => setupAdvice(issue),
                null => label,
              },
              state: unknown
                  ? _CheckState.unknown
                  : switch (issues.intersection(related).firstOrNull) {
                      null => _CheckState.ok,
                      final issue when issue.blocking => _CheckState.bad,
                      _ => _CheckState.warn,
                    },
            ),
          const Divider(color: Colors.white24, height: 12),
          // Như Pushup RPG: máy trước mặt để người chơi xem được trận đấu.
          // Đếm bằng độ sâu vai–cổ tay, 96,5% trên 12 clip chính diện.
          const Text(
            'Mẹo: dựng điện thoại đứng trên sàn, trước mặt, cách bàn tay '
            '0,6–1 m, camera thấy đầu, vai và hai tay.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

enum _CheckState { ok, warn, bad, unknown }

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.label, required this.state});

  final String label;
  final _CheckState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (state) {
      _CheckState.ok => (Icons.check_circle, Colors.lightGreenAccent),
      _CheckState.warn => (Icons.error, Colors.amberAccent),
      _CheckState.bad => (Icons.cancel, Colors.redAccent),
      _CheckState.unknown => (Icons.radio_button_unchecked, Colors.white38),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: state == _CheckState.unknown
                    ? Colors.white38
                    : Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
