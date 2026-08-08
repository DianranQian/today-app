import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 子应用配置集：每个子应用可保存多份数据快照（默认/用户自定义/AI 汇总），
/// 可切换、导出、删除。数据为各模型 toJson 的列表。
class ProfileStore {
  /// 默认配置名（虚拟，不落盘）
  static const String defaultProfile = '默认';

  static String _listKey(String appId) => '${appId}_profile_list';
  static String _dataKey(String appId, String name) => '${appId}_profile_$name';

  /// 用户配置名列表（不含「默认」）
  static Future<List<String>> profileNames(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_listKey(appId));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// 保存/覆盖一份配置
  static Future<void> save(String appId, String name,
      List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dataKey(appId, name), jsonEncode(items));
    final names = await profileNames(appId);
    if (!names.contains(name)) {
      names.add(name);
      await prefs.setString(_listKey(appId), jsonEncode(names));
    }
  }

  /// 读取配置数据（空 = 不存在）
  static Future<List<Map<String, dynamic>>> load(String appId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dataKey(appId, name));
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 删除配置
  static Future<void> remove(String appId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dataKey(appId, name));
    final names = await profileNames(appId);
    names.remove(name);
    await prefs.setString(_listKey(appId), jsonEncode(names));
  }
}
