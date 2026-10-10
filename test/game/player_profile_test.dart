import 'package:flutter_test/flutter_test.dart';
import 'package:solo_pushing_up/art/hero_art.dart';
import 'package:solo_pushing_up/game/player_profile.dart';
import 'package:solo_pushing_up/rep/pushup_counter.dart';

void main() {
  test('BMI và phân loại theo ngưỡng châu Á', () {
    final p = PlayerProfile(heightCm: 170, weightKg: 65);
    expect(p.bmi, closeTo(22.5, 0.05));
    expect(p.bmiClass, BmiClass.normal);
    expect(PlayerProfile(weightKg: 70).bmiClass, BmiClass.overweight);
    expect(PlayerProfile(weightKg: 80).bmiClass, BmiClass.obese);
    expect(PlayerProfile(weightKg: 50).bmiClass, BmiClass.underweight);
  });

  test('ước tính mỡ Deurenberg: nữ cao hơn nam cùng số đo', () {
    final male = PlayerProfile(age: 30, heightCm: 170, weightKg: 70);
    final female = PlayerProfile(
      sex: HeroSex.female,
      age: 30,
      heightCm: 170,
      weightKg: 70,
    );
    // 1,2 × 24,2 + 0,23 × 30 − 10,8 − 5,4 ≈ 19,8%.
    expect(male.estimatedBodyFat, closeTo(19.8, 0.2));
    expect(
      female.estimatedBodyFat - male.estimatedBodyFat,
      closeTo(10.8, 0.01),
    );
  });

  test('tự nhập tỉ lệ mỡ thì dùng số tự nhập', () {
    final p = PlayerProfile(bodyFatOverride: 12);
    expect(p.bodyFat, 12);
  });

  test('nặng hơn thì nhân vật đầy đặn hơn; cao hơn thì to hơn', () {
    final slim = PlayerProfile(weightKg: 55).look;
    final heavy = PlayerProfile(weightKg: 110).look;
    expect(heavy.fat, greaterThan(slim.fat));
    expect(PlayerProfile(heightCm: 190).look.height, greaterThan(1));
    expect(PlayerProfile(heightCm: 150).look.height, lessThan(1));
  });

  test('sức nâng mỗi rep: chuẩn 64%, chống gối 49% cân nặng', () {
    final p = PlayerProfile(weightKg: 70);
    expect(p.liftPerRepKg(PushupMode.standard), closeTo(44.8, 0.01));
    expect(p.liftPerRepKg(PushupMode.knee), closeTo(34.3, 0.01));
  });

  test('lưu và đọc lại giữ nguyên', () {
    final p = PlayerProfile(
      name: 'Lan',
      sex: HeroSex.female,
      age: 22,
      heightCm: 158,
      weightKg: 49,
      skinTone: 4,
      hairStyle: HairStyle.bun,
      hairColor: 3,
      bodyFatOverride: 24,
    );
    final back = PlayerProfile.decode(p.encode());
    expect(back.toJson(), p.toJson());
  });
}
