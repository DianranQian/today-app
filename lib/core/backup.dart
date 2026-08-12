import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scheme_store.dart';
import 'language.dart';

/// 数据备份：全量/子应用级 导出导入（JSON + 图片打包为 ZIP）
class BackupService {
  /// 全局共享键（历史/设置/偏好，方案化列表键由 [SchemeStore] 动态展开）
  static const _globalKeys = [
    'history', 'settings', 'eat_avoid', 'plan_items',
    'go_history', 'go_avoid_recent',
    'wear_history', 'wear_avoid_recent', 'wear_gender', 'wear_group',
    'contact_avoid_recent', 'contact_default_frequency',
    'app_color_eat', 'app_color_go', 'app_color_wear', 'app_color_contact',
    'app_color_todo',
    'app_language',
  ];

  /// 布尔类型键（getBool/setBool 存取，备份时转字符串）
  static const _boolKeys = {
    'go_avoid_recent', 'wear_avoid_recent', 'contact_avoid_recent',
    'eat_avoid_recent',
  };

  static bool _isBoolKey(String key) => _boolKeys.contains(key);

  static String? _readPref(SharedPreferences prefs, String key) {
    if (_isBoolKey(key)) {
      final v = prefs.getBool(key);
      return v == null ? null : v.toString();
    }
    return prefs.getString(key);
  }

  static Future<void> _writePref(
      SharedPreferences prefs, String key, String value) async {
    if (_isBoolKey(key)) {
      await prefs.setBool(key, value == 'true');
    } else {
      await prefs.setString(key, value);
    }
  }

  /// 参与备份的全部键：全局键 + 所有方案的方案化数据键 + 方案元数据键
  static Future<Set<String>> allKeys() async {
    final keys = <String>{..._globalKeys};
    for (final appId in SchemeStore.schemeListKeys.keys) {
      keys.addAll(await _schemeKeysFor(appId));
    }
    return keys;
  }

  /// 某子应用的方案元数据键 + 所有方案的数据键
  static Future<Set<String>> _schemeKeysFor(String appId) async {
    final keys = <String>{
      '${appId}_schemes',
      '${appId}_scheme_current',
      '${appId}_scheme_random',
    };
    final schemes = await SchemeStore.list(appId);
    final listKeys = SchemeStore.schemeListKeys[appId] ?? const <String, String>{};
    for (final scheme in schemes) {
      for (final lk in listKeys.keys) {
        keys.add(SchemeStore.dataKey(appId, scheme, lk));
      }
    }
    return keys;
  }

  /// 各子应用的数据键（子应用级导入导出，动态含方案键）
  static Future<Set<String>> appKeys(String appId) async {
    final keys = <String>{
      if (appId == 'eat') ...['history', 'settings', 'eat_avoid'],
      if (appId == 'go') ...['go_history', 'go_avoid_recent'],
      if (appId == 'wear')
        ...['wear_history', 'wear_avoid_recent', 'wear_gender', 'wear_group'],
      if (appId == 'contact')
        ...['contact_avoid_recent', 'contact_default_frequency'],
    };
    keys.addAll(await _schemeKeysFor(appId));
    return keys;
  }

  static const _imageExts = {'.jpg', '.jpeg', '.png', '.webp', '.heic'};

  static Future<Directory> _imagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}${Platform.pathSeparator}images');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// 从数据 JSON 中收集 imagePath 引用（用于子应用导出时打包图片）
  static Set<String> _collectImagePaths(Map<String, dynamic> data) {
    final paths = <String>{};
    for (final v in data.values) {
      if (v is! String || v.isEmpty) continue;
      try {
        final parsed = jsonDecode(v);
        if (parsed is List) {
          for (final item in parsed) {
            if (item is Map && item['imagePath'] is String) {
              paths.add(item['imagePath'] as String);
            }
          }
        }
      } catch (_) {}
    }
    return paths;
  }

  static Future<Map<String, dynamic>> _collectKeys(
      List<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in keys) {
      final v = _readPref(prefs, key);
      if (v != null) data[key] = v;
    }
    return data;
  }

  /// 导出：生成 ZIP 备份文件路径（含 data.json + images/）
  static Future<File> exportBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in await allKeys()) {
      final v = _readPref(prefs, key);
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

  /// 导出纯 JSON（数据，不含照片）
  static Future<File> exportJson() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in await allKeys()) {
      final v = _readPref(prefs, key);
      if (v != null) data[key] = v;
    }
    final docs = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().split('.').first
        .replaceAll(':', '').replaceAll('-', '').replaceAll('T', '_');
    final file = File('${docs.path}${Platform.pathSeparator}today_data_$ts.json');
    file.writeAsStringSync(jsonEncode(data));
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
      if (data == null) {
        throw Exception(t('备份包缺少 data.json'));
      }
      final prefs = await SharedPreferences.getInstance();
      final allowed = await allKeys();
      for (final entry in data.entries) {
        if (!allowed.contains(entry.key)) continue;
        await _writePref(prefs, entry.key, entry.value as String);
        restored++;
      }
    } else {
      // 纯 JSON：{key: value}
      final data = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)));
      final prefs = await SharedPreferences.getInstance();
      final allowed = await allKeys();
      for (final entry in data.entries) {
        if (!allowed.contains(entry.key)) continue;
        await _writePref(prefs, entry.key, entry.value as String);
        restored++;
      }
    }
    return restored;
  }

  /// ===== 子应用级导入导出 =====

  /// 导出单个子应用数据。
  /// [withImages] true → ZIP（数据 + 该子应用引用的图片）；false → 纯 JSON。
  static Future<File> exportApp(String appId,
      {bool withImages = true}) async {
    final keys = await appKeys(appId);
    if (keys.isEmpty) {
      throw Exception(t('未知子应用：$appId', 'Unknown app: $appId'));
    }
    final data = await _collectKeys(keys.toList());
    final docs = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().toIso8601String().split('.').first
        .replaceAll(':', '').replaceAll('-', '').replaceAll('T', '_');

    if (!withImages) {
      final file = File(
          '${docs.path}${Platform.pathSeparator}${appId}_data_$ts.json');
      file.writeAsStringSync(jsonEncode(data));
      return file;
    }

    final archive = Archive();
    archive.addFile(ArchiveFile.string('data.json', jsonEncode(data)));
    // 收集该子应用引用到的图片并打包
    final imgDir = await _imagesDir();
    final paths = _collectImagePaths(data);
    for (final rel in paths) {
      final name = rel.split('/').last;
      final src = File('${imgDir.path}${Platform.pathSeparator}$name');
      if (src.existsSync()) {
        archive.addFile(ArchiveFile(
            'images/$name', src.lengthSync(), src.readAsBytesSync()));
      }
    }
    final zipBytes = ZipEncoder().encode(archive);
    final file = File(
        '${docs.path}${Platform.pathSeparator}${appId}_backup_$ts.zip');
    file.writeAsBytesSync(zipBytes!);
    return file;
  }

  /// 导入单个子应用数据（ZIP 或 JSON）。
  /// 返回恢复的键数量；调用方需自行热更新对应 store（load()）。
  static Future<int> importApp(String appId, String path) async {
    final keys = await appKeys(appId);
    if (keys.isEmpty) {
      throw Exception(t('未知子应用：$appId', 'Unknown app: $appId'));
    }
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
      if (data == null) {
        throw Exception(t('备份包缺少 data.json'));
      }
      final prefs = await SharedPreferences.getInstance();
      for (final key in keys) {
        final v = data[key];
        if (v is String && v.isNotEmpty) {
          await _writePref(prefs, key, v);
          restored++;
        }
      }
    } else {
      final data = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(bytes)));
      final prefs = await SharedPreferences.getInstance();
      for (final key in keys) {
        final v = data[key];
        if (v is String && v.isNotEmpty) {
          await _writePref(prefs, key, v);
          restored++;
        }
      }
    }
    return restored;
  }
}
