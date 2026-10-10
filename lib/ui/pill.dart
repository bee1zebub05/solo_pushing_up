import 'package:flutter/material.dart';

/// Nhãn bo tròn cho lời nhắc / sự kiện rep trên màn hình camera.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.color = Colors.black54});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}
