import 'limb.dart';

/// Profile giải phẫu người (đơn vị: nửa bề rộng ở cỡ nhân vật thường, cánh
/// tay trên dài ~30). Anh hùng / thần: dùng `scaled(1.9–2.1)`.
///
/// Mỗi profile tuân thủ: một mặt gần thẳng, mặt kia có khối phồng; đỉnh phồng
/// hai mặt lệch độ cao; thon về đầu mút; rãnh tách nhóm cơ đi từ mép vào.
abstract final class HumanAnatomy {
  /// Cánh tay trên (vai → khuỷu). Trước: cơ vai trước, lõm giữa cơ vai và
  /// bắp tay trước, bắp tay trước phồng thấp. Sau: cơ vai sau, bắp tay sau
  /// (tam đầu) phồng cao hơn bắp tay trước, rồi thẳng xuống khuỷu.
  static const upperArm = MuscleProfile(
    anterior: [
      (0.0, 6.6),
      (0.16, 7.4), // cơ vai trước
      (0.36, 6.0), // lõm: cơ vai bám vào xương cánh tay
      (0.62, 6.6), // bắp tay trước (biceps)
      (0.86, 5.0),
      (1.0, 4.7), // khuỷu
    ],
    posterior: [
      (0.0, 6.8),
      (0.18, 7.0), // cơ vai sau
      (0.42, 7.2), // bắp tay sau (triceps) — cao hơn đỉnh biceps
      (0.72, 5.7), // mặt sau gần thẳng
      (1.0, 4.9),
    ],
    grooves: [
      // Mép dưới cơ vai: chữ V ôm đầu cánh tay, chui vào giữa hai bắp tay.
      Groove([(0.04, -0.95), (0.24, -0.45), (0.36, 0.05), (0.2, 0.92)]),
      // Rãnh tách bắp tay trước / sau.
      Groove([(0.42, 0.05), (0.66, -0.05), (0.88, 0.15)], weight: 0.7),
    ],
  );

  /// Cẳng tay (khuỷu → cổ tay). Trước: cơ cánh tay quay phồng ngay dưới
  /// khuỷu rồi thon nhanh. Sau: gần thẳng theo xương trụ.
  static const forearm = MuscleProfile(
    anterior: [
      (0.0, 4.8),
      (0.2, 6.3), // cơ cánh tay quay (brachioradialis)
      (0.48, 5.1),
      (0.8, 3.9),
      (1.0, 3.8),
    ],
    posterior: [
      (0.0, 4.9),
      (0.14, 5.5), // khối cơ duỗi ngay dưới khuỷu
      (0.5, 4.5),
      (1.0, 3.8), // cổ tay
    ],
    grooves: [
      Groove([(0.04, 0.6), (0.32, 0.15), (0.7, 0.3)], weight: 0.8),
      Groove([(0.12, -0.7), (0.55, -0.45), (0.92, -0.4)], weight: 0.45),
    ],
  );

  /// Nắm đấm: khối hơi to ở đốt ngón.
  static const fist = MuscleProfile(
    anterior: [(0.0, 5.6), (1.0, 6.2)],
    posterior: [(0.0, 5.6), (1.0, 5.8)],
  );

  /// Đùi (hông → gối). Trước: cơ tứ đầu phồng ở 1/3 trên rồi một khối nhỏ
  /// (cơ rộng trong, "giọt nước") ngay trên gối. Sau: mông–gân kheo, phồng
  /// cao rồi gần thẳng.
  static const thigh = MuscleProfile(
    anterior: [
      (0.0, 8.0),
      (0.3, 9.4), // cơ thẳng đùi + cơ rộng ngoài
      (0.62, 7.9),
      (0.84, 7.0), // giọt nước trên gối
      (1.0, 5.9),
    ],
    posterior: [
      (0.0, 8.8), // mông
      (0.16, 8.9),
      (0.5, 7.5), // gân kheo, gần thẳng
      (1.0, 6.2),
    ],
    grooves: [
      // Cơ may chạy chéo từ hông xuống mặt trong gối.
      Groove([(0.04, 0.75), (0.45, 0.15), (0.92, -0.25)], weight: 0.8),
      // Mép trên giọt nước cơ rộng trong.
      Groove([(0.68, 0.95), (0.82, 0.45), (0.96, 0.6)], weight: 0.9),
      // Rãnh tách cơ rộng ngoài / gân kheo.
      Groove([(0.22, -0.55), (0.6, -0.4), (0.9, -0.35)], weight: 0.55),
    ],
  );

  static const thighFemale = MuscleProfile(
    anterior: [(0.0, 8.8), (0.3, 9.8), (0.62, 8.2), (0.84, 7.0), (1.0, 5.9)],
    posterior: [(0.0, 9.6), (0.16, 9.8), (0.5, 8.0), (1.0, 6.2)],
    grooves: [
      Groove([(0.68, 0.95), (0.82, 0.45), (0.96, 0.6)], weight: 0.6),
    ],
  );

  /// Cẳng chân (gối → cổ chân). Trước: ống quyển gần thẳng. Sau: bắp chân
  /// (cơ sinh đôi) phồng cao ở 1/4 trên, thon nhanh thành gân gót.
  static const shin = MuscleProfile(
    anterior: [
      (0.0, 5.9),
      (0.18, 5.6),
      (0.6, 4.6), // ống quyển thẳng
      (0.9, 3.8),
      (1.0, 3.9),
    ],
    posterior: [
      (0.0, 6.2),
      (0.22, 7.7), // cơ sinh đôi
      (0.45, 6.6),
      (0.72, 4.5), // gân gót
      (1.0, 4.0),
    ],
    grooves: [
      // Mép dưới cơ sinh đôi, chéo xuống gân gót.
      Groove([(0.12, -0.35), (0.38, -0.6), (0.6, -0.95)], weight: 0.9),
      // Cơ chày trước dọc ống quyển.
      Groove([(0.1, 0.5), (0.45, 0.35), (0.75, 0.4)], weight: 0.45),
    ],
  );
}

/// Profile giải phẫu mèo lớn (sư tử). Đơn vị: cỡ sư tử boss (nửa bề rộng đùi
/// sau ~22). Phía trước = phía đầu con vật.
abstract final class FelineAnatomy {
  /// Chân trước trên (vai → khuỷu): khối cơ tam đầu sau vai rất dày.
  static const foreUpper = MuscleProfile(
    anterior: [(0.0, 17.0), (0.32, 15.0), (0.75, 12.0), (1.0, 11.0)],
    posterior: [(0.0, 17.0), (0.28, 18.8), (0.6, 14.5), (1.0, 12.2)],
    grooves: [
      Groove([(0.08, -0.9), (0.35, -0.3), (0.62, -0.4)], weight: 1.1),
    ],
  );

  /// Cẳng chân trước (khuỷu → cổ chân): phồng phía trước rồi thon.
  static const foreLower = MuscleProfile(
    anterior: [(0.0, 11.0), (0.25, 12.6), (0.8, 9.0), (1.0, 10.0)],
    posterior: [(0.0, 12.2), (0.3, 10.2), (1.0, 9.6)],
    grooves: [
      Groove([(0.1, 0.5), (0.4, 0.2), (0.75, 0.3)], weight: 0.8),
    ],
  );

  /// Chân sau trên (hông → cổ chân sau): đùi + cơ đùi sau khổng lồ.
  static const hindUpper = MuscleProfile(
    anterior: [(0.0, 21.0), (0.26, 21.8), (0.62, 14.0), (1.0, 8.5)],
    posterior: [(0.0, 21.0), (0.34, 23.0), (0.7, 14.5), (1.0, 9.5)],
    grooves: [
      // Rãnh tách cơ đùi trước / sau, cong theo khối đùi.
      Groove([(0.1, 0.4), (0.38, 0.0), (0.7, -0.25)], weight: 1.2),
      Groove([(0.5, 0.9), (0.66, 0.5), (0.8, 0.55)], weight: 0.7),
    ],
  );

  /// Cổ chân sau → bàn chân: gân gót thẳng phía sau.
  static const hindLower = MuscleProfile(
    anterior: [(0.0, 8.5), (0.4, 8.0), (1.0, 8.5)],
    posterior: [(0.0, 10.0), (0.3, 8.2), (1.0, 8.5)],
  );
}
