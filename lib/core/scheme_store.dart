import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 多方案管理（菜单一 / 菜单二 …）
///
/// 存储键设计（appId = eat/go/wear/contact/todo）：
/// - `{appId}_schemes`：方案名列表 JSON（StringList）
/// - `{appId}_scheme_current`：当前工作区方案名
/// - `{appId}_scheme_random`：参与随机抽取的方案名列表
/// - `{appId}_scheme_{方案名}_{列表键}`：该方案条目数据
///
/// 方案化列表键（旧键 → 方案内键名），历史/设置/忌口等全局键不动。
class SchemeStore {
  /// 默认内置方案名（eat=菜单一 / go=地点集 / wear=衣柜 / contact=电话簿）
  static String defaultSchemeName(String appId) {
    switch (appId) {
      case 'eat': return '菜单一';
      case 'go': return '地点集';
      case 'wear': return '衣柜';
      case 'contact': return '电话簿';
      default: return '方案一';
    }
  }

  /// 各子应用的方案化列表键：方案内键名 → 旧键名（迁移兜底用）
  /// 注：todo（待办）不做方案，直接读写 `todo_items`
  static const Map<String, Map<String, String>> schemeListKeys = {
    'eat': {'dishes': 'dishes', 'staples': 'staples', 'drinks': 'drinks'},
    'go': {'places': 'go_places'},
    'wear': {'outfits': 'wear_outfits'},
    'contact': {'contacts': 'contact_contacts'},
  };

  /// 方案或随机池变化时通知（值为 appId，壳层/home 监听后重载）
  static final ValueNotifier<String> notifier = ValueNotifier<String>('');

  static final Map<String, String> _currentCache = {};

  static String _schemesKey(String appId) => '${appId}_schemes';
  static String _currentKey(String appId) => '${appId}_scheme_current';
  static String _randomKey(String appId) => '${appId}_scheme_random';
  static String dataKey(String appId, String scheme, String listKey) =>
      '${appId}_scheme_${scheme}_$listKey';

  /// 当前方案（内存缓存优先；saveNow 等同步场景使用）
  static String cachedCurrent(String appId) {
    final c = _currentCache[appId];
    if (c != null && c.isNotEmpty) return c;
    return defaultSchemeName(appId);
  }

  static Future<List<String>> list(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_schemesKey(appId)) ?? <String>[];
  }

  static Future<String> current(String appId) async {
    final cached = _currentCache[appId];
    if (cached != null && cached.isNotEmpty) return cached;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_currentKey(appId));
    if (v != null && v.isNotEmpty) {
      _currentCache[appId] = v;
      return v;
    }
    return defaultSchemeName(appId);
  }

  /// 参与随机的方案列表；未设置时默认仅当前方案
  static Future<List<String>> randomPool(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getStringList(_randomKey(appId));
    if (v == null || v.isEmpty) return [await current(appId)];
    return v;
  }

  /// 旧数据迁移（零破坏）：旧键复制到默认方案键，旧键保留不删
  static Future<void> migrateLegacy(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_schemesKey(appId))) return;
    final defaultName = defaultSchemeName(appId);
    final legacy = schemeListKeys[appId] ?? const <String, String>{};
    for (final entry in legacy.entries) {
      final v = prefs.getString(entry.value);
      if (v != null && v.isNotEmpty) {
        prefs.setString(dataKey(appId, defaultName, entry.key), v);
      }
    }
    prefs.setStringList(_schemesKey(appId), [defaultName]);
    prefs.setString(_currentKey(appId), defaultName);
    prefs.setStringList(_randomKey(appId), [defaultName]);
    _currentCache[appId] = defaultName;
  }

  /// 默认名迁移：早期版本默认名是「菜单一/方案一」，
  /// 若用户只有一个默认方案（未新建自定义方案），自动重命名为当前默认名
  static Future<void> migrateDefaultName(String appId) async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_schemesKey(appId))) return;
    final newName = defaultSchemeName(appId);
    final list = prefs.getStringList(_schemesKey(appId)) ?? <String>[];
    if (list.length != 1) return; // 已有自定义方案，不打扰
    final old = list.first;
    if (old == newName) return;
    if (old != '菜单一' && old != '方案一') return; // 用户自定义名，不动
    final keys = schemeListKeys[appId] ?? const <String, String>{};
    for (final entry in keys.entries) {
      final src = dataKey(appId, old, entry.key);
      final v = prefs.getString(src);
      if (v != null && v.isNotEmpty) {
        await prefs.setString(dataKey(appId, newName, entry.key), v);
        await prefs.remove(src);
      }
    }
    await prefs.setStringList(_schemesKey(appId), [newName]);
    await prefs.setString(_currentKey(appId), newName);
    final rp = prefs.getStringList(_randomKey(appId)) ?? <String>[];
    if (rp.length == 1) {
      await prefs.setStringList(_randomKey(appId), [newName]);
    }
    _currentCache[appId] = newName;
  }

  /// 新建空白方案（重名拒绝）
  static Future<void> create(String appId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('方案名不能为空');
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_schemesKey(appId)) ?? <String>[];
    if (list.contains(trimmed)) throw ArgumentError('方案已存在');
    list.add(trimmed);
    await prefs.setStringList(_schemesKey(appId), list);
    notify(appId);
  }

  /// 重命名（连带迁移数据键 + 更新 current/random）
  static Future<void> rename(
      String appId, String oldName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || trimmed == oldName) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_schemesKey(appId)) ?? <String>[];
    if (!list.contains(oldName)) return;
    if (list.contains(trimmed)) throw ArgumentError('方案已存在');
    final keys = schemeListKeys[appId] ?? const <String, String>{};
    for (final entry in keys.entries) {
      final src = dataKey(appId, oldName, entry.key);
      final v = prefs.getString(src);
      if (v != null && v.isNotEmpty) {
        await prefs.setString(dataKey(appId, trimmed, entry.key), v);
        await prefs.remove(src);
      }
    }
    list[list.indexOf(oldName)] = trimmed;
    await prefs.setStringList(_schemesKey(appId), list);
    if (prefs.getString(_currentKey(appId)) == oldName) {
      await prefs.setString(_currentKey(appId), trimmed);
      _currentCache[appId] = trimmed;
    }
    final rp = prefs.getStringList(_randomKey(appId)) ?? <String>[];
    if (rp.contains(oldName)) {
      await prefs.setStringList(
          _randomKey(appId), rp.map((n) => n == oldName ? trimmed : n).toList());
    }
    notify(appId);
  }

  /// 删除方案（当前方案禁止删除；连带删除数据键）
  static Future<void> remove(String appId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_currentKey(appId)) == name) {
      throw ArgumentError('不能删除当前方案');
    }
    final list = prefs.getStringList(_schemesKey(appId)) ?? <String>[];
    if (!list.contains(name)) return;
    list.remove(name);
    await prefs.setStringList(_schemesKey(appId), list);
    final keys = schemeListKeys[appId] ?? const <String, String>{};
    for (final entry in keys.entries) {
      await prefs.remove(dataKey(appId, name, entry.key));
    }
    final rp = prefs.getStringList(_randomKey(appId)) ?? <String>[];
    if (rp.contains(name)) {
      await prefs.setStringList(_randomKey(appId), rp.where((n) => n != name).toList());
    }
    notify(appId);
  }

  /// 切换工作区方案（调用方需 await store.load() 刷新内存）
  static Future<void> switchTo(String appId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_schemesKey(appId)) ?? <String>[];
    if (!list.contains(name)) return;
    await prefs.setString(_currentKey(appId), name);
    _currentCache[appId] = name;
    notify(appId);
  }

  /// 设置参与随机的方案列表
  static Future<void> setRandomPool(String appId, List<String> names) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_randomKey(appId), names);
    notify(appId);
  }

  /// 合并随机池原始条目（按 name 去重）。
  /// 返回 null 表示随机池仅当前方案（调用方直接用内存数据即可）。
  static Future<List<Map<String, dynamic>>?> rawPoolItems(
      String appId, String listKey) async {
    final names = await randomPool(appId);
    final cur = await current(appId);
    if (names.length == 1 && names.first == cur) return null;
    final prefs = await SharedPreferences.getInstance();
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final name in names) {
      final json = prefs.getString(dataKey(appId, name, listKey));
      if (json == null || json.isEmpty) continue;
      try {
        for (final e in jsonDecode(json) as List) {
          final m = e as Map<String, dynamic>;
          final n = m['name'] as String? ?? '';
          if (n.isEmpty || seen.contains(n)) continue;
          seen.add(n);
          result.add(m);
        }
      } catch (_) {}
    }
    return result;
  }

  /// 通知壳层/设置页刷新。
  /// ValueNotifier 值不变时不通知，先置空再写回，保证每次都触发匹配的通知
  static void notify(String appId) {
    notifier.value = '';
    notifier.value = appId;
  }

  @visibleForTesting
  static void resetForTest() {
    _currentCache.clear();
    notifier.value = '';
  }
}
