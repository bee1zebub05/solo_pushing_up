# Đồ hoạ: phong cách game vector (nghiên cứu đêm 10–11/10/2026)

Mục tiêu: nhân vật và boss vẽ hoàn toàn bằng code (`lib/art/`), không mua asset, đủ đẹp để lên store. Chỉ học **kỹ thuật** từ các game đi trước, không sao chép hình.

## 1. Quan sát từ tham khảo

Tham khảo chính là dòng Kingdom Rush (Ironhide): phong cách cartoon nhiều chi tiết, chú trọng đọc được hình ở kích thước nhỏ.

| Đặc điểm | Ghi chú | Áp dụng cho mình |
|---|---|---|
| Tỉ lệ "chunky" | Đầu to, cẳng tay và bàn tay to, bàn chân/giày to, chân ngắn | Cẳng tay to hơn bắp tay, nắm đấm to, sandal to hơn |
| Viền đậm, không đều | Viền dày ở phía khuất sáng, mỏng phía có sáng | Thêm một lớp viền lệch về phía bóng |
| Đổ bóng 3 tông | Màu gốc, mảng bóng sắc cạnh, vệt sáng; chấm bóng loáng nhỏ | Đã có bóng và viền sáng; thêm chấm bóng loáng trên tóc, kim loại, má |
| Biểu cảm mạnh | Nghiến răng, mày chau, mắt nheo | Mặt đổi theo độ gắng sức của rep |
| Bóng tiếp đất | Ellipse tối dưới chân giúp nhân vật "đứng" trên nền | Thêm bóng dưới người khi đứng và khi chống đẩy |
| Boss | To hơn hẳn nhân vật, màu tương phản mạnh (xanh ngọc, tím, cam), mắt phát sáng, dáng gai góc, hiệu ứng phát sáng | Mỗi boss một màu chủ đạo, mắt và đòn có ánh phát sáng |

## 2. Nguyên tắc rút ra

1. **Đọc được ở kích thước điện thoại để trên sàn cách 1 m**: dáng tổng thể quan trọng hơn chi tiết.
2. **Ánh sáng thống nhất**: nguồn sáng trên bên trái cho mọi nhân vật, boss, phông nền (`VectorStyle.lightWorld`).
3. **Viền**: dày ở phía bóng, mỏng ở phía sáng. Đường bên trong (nếp vải, cơ) mỏng hơn viền ngoài.
4. **Boss: hình phải nói lên cơ chế** (đọc được trước khi bị đánh):
   - Thuỷ Tinh: nước dâng thật trên sân khấu.
   - Orochi: thấy rõ đầu bị chém và đầu mọc lại.
   - Fafnir: băng phủ lên khi người chơi nghỉ lâu.
5. **Mỗi kiểu nguy hiểm một màu và hình cố định** trong suốt trận, để người chơi không phải học lại.
6. **Ngân sách hiệu năng**: cả sân khấu dưới 2 ms/khung (đo bằng test trên PC). Không dùng `Path.combine` mỗi khung; phần tĩnh vẽ sẵn thành Picture.

## 3. Nguồn

- [Kingdom Rush (Wikipedia)](https://en.wikipedia.org/wiki/Kingdom_Rush): phong cách cartoon chi tiết, art director Gonzalo Sande.
- [Ironhide: "As long as our fans love Kingdom Rush…"](https://gameworldobserver.com/2018/12/06/ironhide-long-fans-love-kingdom-rush-will-continue-working): giữ phong cách cartoon, thêm chi tiết và hoạt hình.
- [Blender Studio: cartoon character shading](https://studio.blender.org/blog/cartoon-character-shading-with-geometry-nodes): viền là yếu tố chính giúp nhân vật dễ đọc; viền sáng theo góc nhấn dáng.
- [Tuts+: vector anime character, coloring](https://design.tutsplus.com/tutorials/creating-a-vector-anime-character-in-adobe-photoshop-part-2-coloring--vector-8797): cel shading là mảng bóng sắc cạnh, hợp với vector.
- [Enemy telegraph shape language (2026)](https://gamineai.com/blog/enemy-telegraph-shape-language-top-down-boss-fights-fast-visual-consistency-audit-2026) và [Designing for difficulty readability](https://gamedeveloper.com/blogs/designing-for-difficulty-readability-in-arpgs): dáng boss báo trước kiểu tấn công; dấu hiệu nhất quán.
- Ảnh tham khảo Kingdom Rush xem qua Google Images (chỉ để học, không lưu, không dùng lại).
