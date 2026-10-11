import 'dart:ui';

/// Bộ đệm `Picture` theo khoá, bỏ hình lâu không dùng nhất (LRU).
///
/// Dùng cho phần vẽ đắt về CPU (dựng đường cong, bó cơ…) mà đầu vào lặp
/// lại: làm tròn đầu vào (góc, tư thế, biểu cảm) thành khoá, lần đầu ghi
/// lệnh vẽ, các lần sau chỉ `drawPicture`. Khác [RasterLayer] (chụp thành
/// ảnh, tiết kiệm GPU), `Picture` vẫn được GPU tô lại mỗi khung nhưng không
/// tốn bộ nhớ ảnh và nét vẫn sắc ở mọi độ phóng.
class PictureCache<K> {
  PictureCache({this.maxEntries = 200});

  final int maxEntries;
  final Map<K, Picture> _map = {};

  int hits = 0;
  int misses = 0;

  int get length => _map.length;

  /// Lấy hình theo [key]; chưa có thì ghi bằng [record].
  Picture get(K key, void Function(Canvas canvas) record) {
    var picture = _map.remove(key);
    if (picture == null) {
      misses++;
      final recorder = PictureRecorder();
      record(Canvas(recorder));
      picture = recorder.endRecording();
      while (_map.length >= maxEntries) {
        _map.remove(_map.keys.first)?.dispose();
      }
    } else {
      hits++;
    }
    _map[key] = picture; // đưa lên cuối: vừa dùng
    return picture;
  }

  /// Vẽ hình theo [key] lên [canvas] (ghi nếu chưa có).
  void draw(Canvas canvas, K key, void Function(Canvas canvas) record) =>
      canvas.drawPicture(get(key, record));

  void clear() {
    for (final p in _map.values) {
      p.dispose();
    }
    _map.clear();
  }
}
