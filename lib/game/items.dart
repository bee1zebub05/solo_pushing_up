/// Vật phẩm nhận khi qua một kỳ công lần đầu. Lưu và so sánh theo [id];
/// [name] chỉ để hiện, đổi tên không làm mất đồ đã có.
class Item {
  const Item({required this.id, required this.name});

  final String id;
  final String name;

  @override
  String toString() => name;
}

const nemeanPelt = Item(id: 'nemean_pelt', name: 'Áo choàng da sư tử');
const dragonScaleShield = Item(
  id: 'dragon_scale_shield',
  name: 'Khiên vảy rồng',
);
const kusanagi = Item(id: 'kusanagi', name: 'Kiếm Kusanagi');
const nineManeHorse = Item(id: 'nine_mane_horse', name: 'Ngựa chín hồng mao');

/// Kỳ công Heian: quạt lông của Sutoku (chưa có hình trên nhân vật).
const tenguFan = Item(id: 'tengu_fan', name: 'Quạt lông tengu');

const allItems = [
  nemeanPelt,
  dragonScaleShield,
  kusanagi,
  tenguFan,
  nineManeHorse,
];

/// Tìm vật phẩm theo [id]. Bản lưu cũ ghi tên thay vì id, nên tên cũng nhận.
Item? itemById(String idOrLegacyName) {
  for (final item in allItems) {
    if (item.id == idOrLegacyName || item.name == idOrLegacyName) return item;
  }
  return null;
}
