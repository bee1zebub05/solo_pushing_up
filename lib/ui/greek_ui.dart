import 'package:flutter/material.dart';

/// Bảng màu giao diện "đền cổ": nền gỗ sẫm, khung đồng–vàng, chữ ngà.
abstract final class GreekUi {
  static const gold = Color(0xFFE8B83A);
  static const goldDim = Color(0xFF9A7A2E);
  static const panel = Color(0xFF2B211A);
  static const panelTop = Color(0xFF33281F);
  static const ink = Color(0xFFF2E6CC);
  static const inkDim = Color(0xFFBFAE90);
  static const background = Color(0xFF1C1612);
}

/// Dải hoa văn chìa khoá Hy Lạp (meander) vẽ bằng nét vàng.
class MeanderPainter extends CustomPainter {
  const MeanderPainter({this.color = GreekUi.gold});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    if (h <= 0) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeJoin = StrokeJoin.miter;
    final path = Path()..moveTo(0, h);
    for (var x = 0.0; x + h * 1.5 <= size.width; x += h * 1.5) {
      path
        ..lineTo(x, 0)
        ..lineTo(x + h, 0)
        ..lineTo(x + h, h * 0.66)
        ..lineTo(x + h * 0.5, h * 0.66)
        ..lineTo(x + h * 0.5, h * 0.33)
        ..moveTo(x + h, h)
        ..lineTo(x + h * 1.5, h);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(MeanderPainter old) => old.color != color;
}

/// Khung bảng kiểu đền cổ: nền gỗ sẫm chuyển nhẹ, viền vàng mảnh, góc bo
/// nhỏ, bóng đổ mềm. [highlight] làm viền sáng hơn (thẻ đang chọn/mở).
class GreekPanel extends StatelessWidget {
  const GreekPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.dimmed = false,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool dimmed;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final border = dimmed
        ? GreekUi.goldDim.withValues(alpha: 0.35)
        : highlight
        ? GreekUi.gold
        : GreekUi.goldDim;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [GreekUi.panelTop, GreekUi.panel],
          ),
          border: Border.all(color: border, width: highlight ? 2 : 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Tiêu đề mục: chữ in hoa giãn cách màu vàng, hai bên là dải meander.
class GreekHeading extends StatelessWidget {
  const GreekHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
      color: GreekUi.gold,
      letterSpacing: 2.4,
      fontWeight: FontWeight.w700,
    );
    const band = SizedBox(
      height: 7,
      child: CustomPaint(painter: MeanderPainter(color: GreekUi.goldDim)),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          const SizedBox(width: 18, child: band),
          const SizedBox(width: 10),
          Text(text.toUpperCase(), style: style),
          const SizedBox(width: 10),
          const Expanded(child: band),
        ],
      ),
    );
  }
}
