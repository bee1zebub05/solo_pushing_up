import 'raster_layer.dart';

/// Ngân sách chung cho mọi [RasterLayer] đang giữ ảnh.
///
/// - [scale]: số điểm ảnh thật mỗi đơn vị sân khấu (sân khấu đặt theo màn
///   hình khi đổi kích thước).
/// - [maxScale]: trần của [scale] — trên trần thì ảnh hơi mềm nhưng bộ nhớ
///   không phình theo bình phương độ phân giải (máy nằm ngang 2400 px).
/// - [budgetBytes]: tổng bộ nhớ ảnh tối đa; vượt thì giải phóng ảnh lâu
///   không vẽ nhất (LRU). Ảnh vừa vẽ trong [protectMs] gần nhất không bị
///   giải phóng (đang hiện trên màn hình) — khi đó cho vượt tạm và ghi lại.
class RasterBudget {
  RasterBudget({
    this.scale = 2.7,
    this.maxScale = 3.6,
    this.budgetBytes = 96 * 1024 * 1024,
    this.protectMs = 750,
    int Function()? clock,
  }) : _clock = clock ?? _defaultClock;

  /// Ngân sách mặc định dùng chung.
  static RasterBudget shared = RasterBudget();

  static final Stopwatch _watch = Stopwatch()..start();
  static int _defaultClock() => _watch.elapsedMilliseconds;

  final int Function() _clock;
  double scale;
  double maxScale;
  int budgetBytes;
  int protectMs;

  /// Lần vượt ngân sách gần nhất mà không giải phóng được (để log / test).
  int overBudgetEvents = 0;

  final Set<RasterLayer> _live = {};

  /// Độ phân giải hiệu dụng (đã áp trần).
  double get effectiveScale => scale < maxScale ? scale : maxScale;

  /// Tổng byte của mọi ảnh đang giữ.
  int get bytes {
    var sum = 0;
    for (final l in _live) {
      sum += l.bytes;
    }
    return sum;
  }

  int get liveCount => _live.length;

  int now() => _clock();

  /// Gọi khi một lớp vừa tạo ảnh mới: thêm vào danh sách rồi giải phóng
  /// các lớp cũ nhất cho tới khi về lại ngân sách.
  void admit(RasterLayer layer) {
    _live.add(layer);
    trim(keep: layer);
  }

  /// Lớp đã tự giải phóng ảnh.
  void release(RasterLayer layer) => _live.remove(layer);

  /// Giải phóng ảnh lâu không vẽ nhất cho tới khi tổng ≤ [budgetBytes].
  void trim({RasterLayer? keep}) {
    var total = bytes;
    if (total <= budgetBytes) return;
    final t = now();
    final candidates = _live.where((l) => l != keep).toList()
      ..sort((a, b) => a.lastPaintMs.compareTo(b.lastPaintMs));
    for (final l in candidates) {
      if (total <= budgetBytes) break;
      if (t - l.lastPaintMs < protectMs) continue;
      total -= l.bytes;
      l.dispose();
    }
    if (total > budgetBytes) overBudgetEvents++;
  }

  /// Giải phóng tất cả (rời màn chơi, app vào nền, máy báo thiếu bộ nhớ).
  void purge() {
    for (final l in _live.toList()) {
      l.dispose();
    }
  }
}
