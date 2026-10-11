/// Ảnh chụp sẵn cho lớp tĩnh của sân khấu 2D.
///
/// Vấn đề: GPU điện thoại tốn nhiều nhất khi phải tô lại hàng nghìn đường
/// cong vector mỗi khung. Chụp lớp tĩnh thành ảnh một lần rồi mỗi khung chỉ
/// vẽ ảnh giảm thời gian tô từ ~38 ms xuống ~15 ms (đo trên Snapdragon 720G).
///
/// Cái giá là bộ nhớ GPU: một lớp toàn màn hình ở 2400 px ngang chiếm ~19 MB.
/// Thư viện giữ mọi ảnh trong một ngân sách chung ([RasterBudget]): vượt
/// ngân sách thì giải phóng ảnh lâu không vẽ nhất, và giới hạn số điểm ảnh
/// mỗi đơn vị sân khấu ([RasterBudget.maxScale]).
library;

export 'src/budget.dart';
export 'src/picture_cache.dart';
export 'src/raster_layer.dart';
