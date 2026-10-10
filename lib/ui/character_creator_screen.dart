import 'package:flutter/material.dart';

import '../art/hero_art.dart';
import '../game/player_profile.dart';
import '../game/profile_store.dart';
import '../rep/pushup_counter.dart';
import 'hero_preview.dart';

/// Tạo / sửa nhân vật: ngoại hình và số đo cơ thể (chỉ lưu trên máy).
class CharacterCreatorScreen extends StatefulWidget {
  const CharacterCreatorScreen({super.key, this.initial, this.cloak = false});

  /// null = tạo mới (lần đầu mở app).
  final PlayerProfile? initial;

  /// Đã có Áo choàng da sư tử: cho xem nhân vật khi khoác áo.
  final bool cloak;

  @override
  State<CharacterCreatorScreen> createState() => _CharacterCreatorScreenState();
}

class _CharacterCreatorScreenState extends State<CharacterCreatorScreen> {
  late final PlayerProfile _p = widget.initial?.copy() ?? PlayerProfile();
  late final _name = TextEditingController(text: _p.name);
  bool _pushups = false;
  bool _showCloak = false;

  bool get _firstRun => widget.initial == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _update(void Function() change) => setState(change);

  void _setSex(HeroSex sex) => _update(() {
    // Đổi giới tính thì gợi ý kiểu tóc hợp lý, người chơi vẫn đổi lại được.
    if (sex != _p.sex) {
      _p.hairStyle = sex == HeroSex.female
          ? HairStyle.ponytail
          : HairStyle.curly;
    }
    _p.sex = sex;
  });

  Future<void> _save() async {
    _p.name = _name.text.trim();
    await ProfileStore.save(_p);
    if (mounted) Navigator.of(context).pop(_p);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_firstRun ? 'Tạo người kế nhiệm' : 'Sửa nhân vật'),
        automaticallyImplyLeading: !_firstRun,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 240,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: HeroPreview(
                      look: _p.look,
                      pushups: _pushups,
                      cloak: _showCloak,
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Đứng')),
                        ButtonSegment(value: true, label: Text('Hít đất')),
                      ],
                      selected: {_pushups},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) =>
                          setState(() => _pushups = s.single),
                    ),
                  ),
                  if (widget.cloak)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: FilterChip(
                        label: const Text('Áo choàng'),
                        selected: _showCloak,
                        onSelected: (v) => setState(() => _showCloak = v),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Tên người kế nhiệm',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<HeroSex>(
                    segments: const [
                      ButtonSegment(
                        value: HeroSex.male,
                        label: Text('Nam'),
                        icon: Icon(Icons.male),
                      ),
                      ButtonSegment(
                        value: HeroSex.female,
                        label: Text('Nữ'),
                        icon: Icon(Icons.female),
                      ),
                    ],
                    selected: {_p.sex},
                    onSelectionChanged: (s) => _setSex(s.single),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chỉ khác ngoại hình — sức mạnh và cách chơi như nhau.',
                    style: theme.textTheme.bodySmall,
                  ),
                  _section(theme, 'Cơ thể'),
                  _slider(
                    label: 'Tuổi',
                    value: _p.age.toDouble(),
                    min: 10,
                    max: 80,
                    text: '${_p.age}',
                    onChanged: (v) => _update(() => _p.age = v.round()),
                  ),
                  _slider(
                    label: 'Chiều cao',
                    value: _p.heightCm,
                    min: 120,
                    max: 210,
                    text: '${_p.heightCm.round()} cm',
                    onChanged: (v) =>
                        _update(() => _p.heightCm = v.roundToDouble()),
                  ),
                  _slider(
                    label: 'Cân nặng',
                    value: _p.weightKg,
                    min: 30,
                    max: 180,
                    text: '${_p.weightKg.round()} kg',
                    onChanged: (v) =>
                        _update(() => _p.weightKg = v.roundToDouble()),
                  ),
                  _bodyFat(theme),
                  _stats(theme),
                  _section(theme, 'Màu da'),
                  _swatches(
                    colors: skinTones,
                    selected: _p.skinTone,
                    onTap: (i) => _update(() => _p.skinTone = i),
                  ),
                  _section(theme, 'Kiểu tóc'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final style in HairStyle.values)
                        ChoiceChip(
                          label: Text(style.label),
                          selected: _p.hairStyle == style,
                          onSelected: (_) =>
                              _update(() => _p.hairStyle = style),
                        ),
                    ],
                  ),
                  _section(theme, 'Màu tóc'),
                  _swatches(
                    colors: hairColors,
                    selected: _p.hairColor,
                    onTap: (i) => _update(() => _p.hairColor = i),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: Icon(_firstRun ? Icons.play_arrow : Icons.check),
                    label: Text(_firstRun ? 'Bắt đầu hành trình' : 'Lưu'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Chiều cao, cân nặng chỉ lưu trên máy này, dùng để vẽ '
                    'nhân vật và tính sức nâng mỗi rep.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(title, style: theme.textTheme.titleSmall),
  );

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String text,
    required ValueChanged<double> onChanged,
  }) => Row(
    children: [
      SizedBox(width: 84, child: Text(label)),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ),
      SizedBox(width: 64, child: Text(text, textAlign: TextAlign.end)),
    ],
  );

  Widget _bodyFat(ThemeData theme) {
    final auto = _p.bodyFatOverride == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tự tính tỉ lệ mỡ'),
          subtitle: Text(
            auto
                ? 'Ước tính ${_p.estimatedBodyFat.round()}% từ chiều cao, '
                      'cân nặng, tuổi (công thức Deurenberg, sai số ±4%)'
                : 'Bạn tự nhập (ví dụ từ cân đo mỡ)',
          ),
          value: auto,
          onChanged: (v) => _update(
            () => _p.bodyFatOverride = v
                ? null
                : _p.estimatedBodyFat.roundToDouble(),
          ),
        ),
        if (!auto)
          _slider(
            label: 'Tỉ lệ mỡ',
            value: _p.bodyFat,
            min: 5,
            max: 50,
            text: '${_p.bodyFat.round()}%',
            onChanged: (v) =>
                _update(() => _p.bodyFatOverride = v.roundToDouble()),
          ),
      ],
    );
  }

  Widget _stats(ThemeData theme) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BMI ${_p.bmi.toStringAsFixed(1)} · ${_p.bmiClass.label}',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Mỗi rep bạn đẩy khoảng '
            '${_p.liftPerRepKg(PushupMode.standard).round()} kg '
            '(chống gối ${_p.liftPerRepKg(PushupMode.knee).round()} kg)',
          ),
        ],
      ),
    ),
  );

  Widget _swatches({
    required List<Color> colors,
    required int selected,
    required ValueChanged<int> onTap,
  }) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (var i = 0; i < colors.length; i++)
        GestureDetector(
          onTap: () => onTap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(
                color: i == selected ? Colors.amber : Colors.white24,
                width: i == selected ? 3 : 1,
              ),
            ),
          ),
        ),
    ],
  );
}
