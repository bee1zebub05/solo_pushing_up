# Bản release thu gọn mã bằng R8. ML Kit và WorkManager tạo đối tượng bằng
# reflection (gọi constructor không tham số qua tên lớp), R8 không thấy lời
# gọi nên xoá constructor → app crash ngay khi mở:
#   NoSuchMethodException: com.google.mlkit.vision.pose.internal.PoseRegistrar.<init>
#   Failed to create an instance of androidx.work.impl.WorkDatabase

# ML Kit: các ComponentRegistrar và lớp nội bộ được nạp qua tên lớp.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# WorkManager dùng Room: lớp *_Impl sinh tự động được tạo qua reflection.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.** { *; }

# Bản release bỏ model pose "accurate" (build.gradle.kts); plugin vẫn nhắc tới
# lớp của nó trong nhánh chỉ chạy khi chọn PoseDetectionModel.accurate.
-dontwarn com.google.mlkit.vision.pose.accurate.**
