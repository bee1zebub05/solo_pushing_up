import 'dart:convert';
import 'dart:math' as math;

import '../art/hero_art.dart';
import '../rep/pushup_counter.dart';

/// Phân loại BMI theo ngưỡng WHO cho người châu Á (WHO/IASO/IOTF 2000).
enum BmiClass {
  underweight('Thiếu cân'),
  normal('Bình thường'),
  overweight('Thừa cân'),
  obese('Béo phì');

  const BmiClass(this.label);

  final String label;
}

/// Hồ sơ người chơi: ngoại hình nhân vật và số đo cơ thể. Chỉ lưu trên máy.
class PlayerProfile {
  PlayerProfile({
    this.name = '',
    this.sex = HeroSex.male,
    this.age = 25,
    this.heightCm = 170,
    this.weightKg = 65,
    this.skinTone = 2,
    this.hairStyle = HairStyle.curly,
    this.hairColor = 1,
    this.bodyFatOverride,
  });

  String name;
  HeroSex sex;
  int age;
  double heightCm;
  double weightKg;

  /// Chỉ số trong [skinTones] / [hairColors].
  int skinTone;
  HairStyle hairStyle;
  int hairColor;

  /// Tỉ lệ mỡ người chơi tự nhập (%); null = để máy ước tính.
  double? bodyFatOverride;

  double get bmi => weightKg / math.pow(heightCm / 100, 2);

  BmiClass get bmiClass => switch (bmi) {
    < 18.5 => BmiClass.underweight,
    < 23 => BmiClass.normal,
    < 25 => BmiClass.overweight,
    _ => BmiClass.obese,
  };

  /// Ước tính tỉ lệ mỡ từ BMI, tuổi, giới tính (Deurenberg và cộng sự:
  /// người lớn 1991, trẻ em dưới 16 tuổi công thức riêng). Sai số khoảng
  /// ±4%, chỉ để vẽ nhân vật và gợi ý, không phải chẩn đoán.
  double get estimatedBodyFat {
    final male = sex == HeroSex.male ? 1 : 0;
    final value = age < 16
        ? 1.51 * bmi - 0.70 * age - 3.6 * male + 1.4
        : 1.20 * bmi + 0.23 * age - 10.8 * male - 5.4;
    return value.clamp(3, 60).toDouble();
  }

  double get bodyFat => bodyFatOverride ?? estimatedBodyFat;

  /// Khối lượng đẩy lên mỗi rep: hít đất chuẩn ≈ 64% cân nặng, chống gối
  /// ≈ 49% (Ebben và cộng sự, J Strength Cond Res 2011).
  double liftPerRepKg(PushupMode mode) =>
      weightKg * (mode == PushupMode.knee ? 0.49 : 0.64);

  /// Ngoại hình để vẽ nhân vật.
  HeroLook get look {
    // Mức mỡ "gọn" khác nhau giữa nam và nữ; quy về 0–1 cho hình vẽ.
    final lean = sex == HeroSex.male ? 8.0 : 16.0;
    return HeroLook(
      sex: sex,
      skin: skinTones[skinTone.clamp(0, skinTones.length - 1)],
      hair: hairColors[hairColor.clamp(0, hairColors.length - 1)],
      hairStyle: hairStyle,
      fat: ((bodyFat - lean) / 30).clamp(0.0, 1.0),
      height: (1 + (heightCm - 170) / 250).clamp(0.85, 1.15),
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'sex': sex.name,
    'age': age,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'skinTone': skinTone,
    'hairStyle': hairStyle.name,
    'hairColor': hairColor,
    'bodyFatOverride': bodyFatOverride,
  };

  factory PlayerProfile.fromJson(Map<String, Object?> json) => PlayerProfile(
    name: json['name'] as String? ?? '',
    sex: HeroSex.values.asNameMap()[json['sex']] ?? HeroSex.male,
    age: (json['age'] as num?)?.toInt() ?? 25,
    heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170,
    weightKg: (json['weightKg'] as num?)?.toDouble() ?? 65,
    skinTone: (json['skinTone'] as num?)?.toInt() ?? 2,
    hairStyle:
        HairStyle.values.asNameMap()[json['hairStyle']] ?? HairStyle.curly,
    hairColor: (json['hairColor'] as num?)?.toInt() ?? 1,
    bodyFatOverride: (json['bodyFatOverride'] as num?)?.toDouble(),
  );

  String encode() => jsonEncode(toJson());

  static PlayerProfile decode(String source) =>
      PlayerProfile.fromJson(jsonDecode(source) as Map<String, Object?>);

  PlayerProfile copy() => PlayerProfile.fromJson(toJson());
}
