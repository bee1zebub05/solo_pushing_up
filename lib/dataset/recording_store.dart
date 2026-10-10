import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'recording.dart';

/// Lưu bản ghi vào thư mục riêng của app.
///
/// Android: `/sdcard/Android/data/<package>/files/recordings`, lấy về máy tính
/// bằng tool/pull_recordings.ps1.
class RecordingStore {
  static Future<Directory> directory() async {
    final base =
        (Platform.isAndroid ? await getExternalStorageDirectory() : null) ??
        await getApplicationDocumentsDirectory();
    return Directory('${base.path}/recordings').create(recursive: true);
  }

  static Future<File> save(Recording recording) async {
    final dir = await directory();
    final file = File('${dir.path}/${fileName(recording)}');
    return file.writeAsString(recording.encode());
  }

  /// Ví dụ `20261009_221530_standard_15.json`.
  static String fileName(Recording recording) {
    final t = recording.createdAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${t.year}${two(t.month)}${two(t.day)}_'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}';
    return '${stamp}_${recording.mode.name}_${recording.expectedCount ?? 'x'}.json';
  }
}
