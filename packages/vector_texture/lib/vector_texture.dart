/// Hoạ tiết chất liệu cho đồ hoạ vector vẽ bằng code.
///
/// Mỗi hàm trả về các `Path` hình học, chia theo vai trò ánh sáng (khối,
/// rãnh tối, sợi, sống sáng) để app tự tô màu theo bảng màu của mình:
///
/// - [LockSet] / [buildLocks]: lọn lông, bờm, tóc, mào — mọc từ một tâm,
///   uốn theo hướng gió/trọng lực.
/// - [curlRows]: lọn tóc xoăn xếp hàng so le trong một vùng.
/// - [ScaleBody] / [buildScaleBody]: thân rắn/rồng dọc một đường cong: vảy
///   chữ U, sống lưng, dải vảy bụng chia đốt.
/// - [featherRows]: lông vũ xếp ngói (ngọn chĩa xuống).
///
/// Mọi hàm nhận `math.Random` hoặc seed để ảnh luôn giống nhau giữa các
/// lần vẽ (cần cho ảnh xem trước và ảnh chụp sẵn).
library;

export 'src/curls.dart';
export 'src/feathers.dart';
export 'src/locks.dart';
export 'src/scales.dart';
