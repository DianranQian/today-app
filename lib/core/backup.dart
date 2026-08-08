import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 数据备份：全量导出/导入（JSON + 图片打包为 ZIP）
class BackupService {
  /// 参与备份的 SharedPreferences 键（不含 flutter. 前缀）
  static const _prefKeys = [
    'dishes', 'staples', 'drinks', 'history', 'settings',
    'go_places', 'go_history',
    'wear_outfits', 'wear_history',
    'contact_contacts',
    'app_color_eat', 'app_color_go', 'app_color_wear', 'app_color_contact',
    'app_amap_key', 'app_deepseek_key',
    'plan_items',
  ];

  static const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};

  static Future<Directory> _imagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}images');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 导出：生成 ZIP 备份文件路径（含 data.json + images/）
  static Future<File> exportBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in _prefKeys) {
      final v = prefs.getString(key);
      if (v != null) data[key] = v;
    }

    final archive = Archive();
    archive.addFile(ArchiveFile.string('data.json', jsonEncode(data)));

    final imgDir = await _imagesDir();
    for (final f in imgDir.listSync().whereType<File>()) {
      archive.addFile(ArchiveFile(
          'images/${f.uri.pathSegments.last}',
          f.lengthSync(),
          f.readAsBytesSync()));
    }

    final zipBytes = ZipEncoder().encode(archive);
    final docs = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().split('.').first
        .replaceAll(':', '').replaceAll('-', '').replaceAll('T', '_');
    final file = File('${docs.path}${Platform.pathSeparator}today_backup_$ts.zip');
    file.writeAsBytesSync(zipBytes!);
    return file;
  }

  /// 导入：解析 ZIP 或纯 JSON 备份，恢复数据与图片。
  /// 返回恢复的键数量；数据写入后需重启应用生效。
  static Future<int> importBackup(String path) async {
    final bytes = File(path).readAsBytesSync();
    int restored = 0;

    if (path.toLowerCase().endsWith('.zip')) {
      final archive = ZipDecoder().decodeBytes(bytes);
      Map<String, dynamic>? data;
      for (final f in archive.files) {
        if (f.isFile) {
          if (f.name == 'data.json') {
            data = Map<String, dynamic>.from(
                jsonDecode(utf8.decode(f.content as List<int>)));
          } else if (f.name.startsWith('images/')) {
            final name = f.name.split('/').last;
            final ext = name.contains('.')
                ? name.substring(name.lastIndexOf('.')).toLowerCase()
                : '';
            if (!_imageExts.contains(ext)) continue;
            final imgDir = await _imagesDir();
            File('${imgDir.path}${Platform.pathSeparator}$name')
                .writeAsBytesSync(f.content as List<int>);
            restored++;
          }
        }
      }
      if (data == null) throw Exception('备份包缺少 data.json');
      final prefs = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        await prefs.setString(entry.key, entry.value as String);
        restored++;
      }
    } else {
      // 纯 JSON：{key: value}
      final data = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)));
      final prefs = await SharedPreferences.getInstance();
      for (final entry in data.entries) {
        await prefs.setString(entry.key, entry.value as String);
        restored++;
      }
    }
    return restored;
  }
}
