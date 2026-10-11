import 'package:flutter/material.dart';

import 'greek_ui.dart';

/// Nhãn bo tròn cho lời nhắc / sự kiện rep trên màn hình camera.
///
/// Kiểu "thẻ đồng": nền theo [color] tối dần xuống dưới (khối nổi), viền
/// sáng mảnh màu vàng đồng, chữ ngà đậm có bóng — đọc được trên cả camera
/// sáng lẫn tối khi người tập liếc nhìn từ sàn.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.color = Colors.black54});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final top = Color.lerp(color, Colors.white, 0.12)!;
    final bottom = Color.lerp(color, Colors.black, 0.3)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GreekUi.gold.withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(
            color: GreekUi.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Color(0xAA000000), blurRadius: 2)],
          ),
        ),
      ),
    );
  }
}
