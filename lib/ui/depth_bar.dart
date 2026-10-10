import 'package:flutter/material.dart';

import '../rep/pushup_counter.dart';

/// Thanh độ sâu dọc (như Pushup RPG): đầy dần khi hạ người, chuyển xanh khi
/// đã đủ sâu để tính rep. Đặt máy trước mặt thì liếc là thấy.
class DepthBar extends StatelessWidget {
  const DepthBar({super.key, required this.snapshot});

  final CounterSnapshot? snapshot;

  /// 0 = tay thẳng, 1 = chạm ngưỡng đủ sâu.
  static double fillOf(CounterSnapshot s) {
    final angle = s.elbowAngle;
    if (angle == null || s.phase == CounterPhase.searching) return 0;
    return ((180 - angle) / (180 - s.bottomThreshold)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    final fill = s == null ? 0.0 : fillOf(s);
    final deep = fill >= 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          deep ? 'ĐỦ' : 'SÂU',
          style: TextStyle(
            color: deep ? Colors.lightGreenAccent : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            width: 18,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.topCenter,
            child: FractionallySizedBox(
              heightFactor: fill,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                decoration: BoxDecoration(
                  color: deep ? Colors.lightGreenAccent : Colors.deepOrange,
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
