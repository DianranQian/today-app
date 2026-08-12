import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/scheme_store.dart';
import 'todo_models.dart';

class TodoDataStore {
  static List<TodoItem> items = [];

  static Future<void> load() async {
    await SchemeStore.migrateLegacy('todo');
    final scheme = await SchemeStore.current('todo');
    final prefs = await SharedPreferences.getInstance();
    var raw = prefs.getString(SchemeStore.dataKey('todo', scheme, 'items'));
    if ((raw == null || raw.isEmpty) && scheme == SchemeStore.defaultSchemeName('todo')) {
      raw = prefs.getString('todo_items');
    }
    if (raw != null && raw.isNotEmpty) {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => TodoItem.fromJson(e as Map<String, dynamic>))
            .where((t) => t.title.isNotEmpty)
            .toList();
      } catch (_) {
        items = [];
      }
    }
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final scheme = SchemeStore.cachedCurrent('todo');
    prefs.setString(SchemeStore.dataKey('todo', scheme, 'items'),
        jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static void add(TodoItem item) {
    items.add(item);
    save();
  }

  static void remove(TodoItem item) {
    items.remove(item);
    save();
  }

  /// 勾选/取消完成
  static void toggle(TodoItem item) {
    item.done = !item.done;
    save();
  }

  /// 清空已完成
  static void clearDone() {
    items.removeWhere((t) => t.done);
    save();
  }

  static void clearAll() {
    items.clear();
    save();
  }

  /// 按日期分组（日期升序，未完成在前）
  static List<(DateTime, List<TodoItem>)> groupByDate() {
    final map = <DateTime, List<TodoItem>>{};
    for (final item in items) {
      final day = DateTime(item.date.year, item.date.month, item.date.day);
      map.putIfAbsent(day, () => []).add(item);
    }
    final groups = map.entries
        .map((e) => (e.key, e.value))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));
    for (final g in groups) {
      g.$2.sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        return 0;
      });
    }
    return groups;
  }

  static int get pendingCount => items.where((t) => !t.done).length;
}
