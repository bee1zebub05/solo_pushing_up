/// Lựa chọn ngoại hình người chơi lưu trong hồ sơ. Chỉ khác hình, chỉ số và
/// cách chơi giống hệt nhau (rules/cottruyen.md mục 2.2). Cách vẽ nằm ở
/// lib/art/ (HeroLook).
enum HeroSex { male, female }

enum HairStyle {
  curly('Xoăn ngắn'),
  buzz('Cắt ngắn'),
  bun('Búi Hy Lạp'),
  ponytail('Đuôi ngựa'),
  long('Tóc dài');

  const HairStyle(this.label);

  final String label;
}
