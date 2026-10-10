import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Nhãn người dùng gắn cho một set vừa ghi.
class RecordingLabels {
  const RecordingLabels({
    required this.expectedCount,
    required this.tags,
    required this.notes,
  });

  final int expectedCount;
  final Map<String, String> tags;
  final String notes;
}

/// Các điều kiện quay, khớp với ma trận biến số trong rules/kehoach-mayao.md.
const _tagOptions = {
  'angle': ('Góc máy', ['chéo', 'ngang', 'chính diện', 'dưới sàn']),
  'distance': ('Khoảng cách', ['<1m', '1–2m', '>2m']),
  'light': ('Ánh sáng', ['sáng', 'vừa', 'tối', 'ngược sáng']),
  'speed': ('Tốc độ', ['chậm', 'vừa', 'nhanh', 'lẫn lộn']),
};

/// Hỏi số rep thật và điều kiện quay. Trả về `null` nếu người dùng bỏ bản ghi.
Future<RecordingLabels?> showLabelDialog(
  BuildContext context, {
  required int counted,
  required Duration duration,
}) => showDialog<RecordingLabels>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _LabelDialog(counted: counted, duration: duration),
);

class _LabelDialog extends StatefulWidget {
  const _LabelDialog({required this.counted, required this.duration});

  final int counted;
  final Duration duration;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final TextEditingController _expected = TextEditingController(
    text: '${widget.counted}',
  );
  final TextEditingController _notes = TextEditingController();
  final Map<String, String> _tags = {};

  @override
  void dispose() {
    _expected.dispose();
    _notes.dispose();
    super.dispose();
  }

  int? get _expectedCount => int.tryParse(_expected.text.trim());

  @override
  Widget build(BuildContext context) {
    final seconds = (widget.duration.inMilliseconds / 1000).toStringAsFixed(1);
    return AlertDialog(
      title: const Text('Lưu bản ghi'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App đếm ${widget.counted} rep trong ${seconds}s.'),
            const SizedBox(height: 12),
            TextField(
              controller: _expected,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Số rep bạn thực sự làm',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            for (final MapEntry(key: key, value: (label, options))
                in _tagOptions.entries) ...[
              const SizedBox(height: 12),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              Wrap(
                spacing: 6,
                children: [
                  for (final option in options)
                    ChoiceChip(
                      label: Text(option),
                      selected: _tags[key] == option,
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _tags[key] = option;
                        } else {
                          _tags.remove(key);
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Ghi chú (áo tối, phòng nhỏ, …)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bỏ'),
        ),
        FilledButton(
          onPressed: _expectedCount == null
              ? null
              : () => Navigator.of(context).pop(
                  RecordingLabels(
                    expectedCount: _expectedCount!,
                    tags: Map.of(_tags),
                    notes: _notes.text.trim(),
                  ),
                ),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
