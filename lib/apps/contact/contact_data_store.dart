import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/scheme_store.dart';
import 'contact_models.dart';

class ContactDataStore {
  static List<ContactItem> contacts = [];
  static bool avoidRecent = true;

  static Future<void> load() async {
    await SchemeStore.migrateLegacy('contact');
    final scheme = await SchemeStore.current('contact');
    final prefs = await SharedPreferences.getInstance();
    avoidRecent = prefs.getBool('contact_avoid_recent') ?? true;

    final contactsJson =
        prefs.getString(SchemeStore.dataKey('contact', scheme, 'contacts'));
    var json = contactsJson;
    if ((json == null || json.isEmpty) && scheme == SchemeStore.defaultSchemeName('contact')) {
      json = prefs.getString('contact_contacts');
    }
    if (json != null && json.isNotEmpty) {
      try {
        final parsed = (jsonDecode(json) as List)
            .map((e) => ContactItem.fromJson(e as Map<String, dynamic>))
            .where((c) => c.name.isNotEmpty)
            .toList();
        contacts = parsed;
      } catch (_) {
        contacts = [];
      }
    } else {
      contacts = [];
    }
  }

  static Future<void> saveNow([SharedPreferences? prefsInstance]) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    final scheme = SchemeStore.cachedCurrent('contact');
    prefs.setString(SchemeStore.dataKey('contact', scheme, 'contacts'),
        jsonEncode(contacts.map((e) => e.toJson()).toList()));
  }

  static Future<void> save() => saveNow();

  /// 随机池联系人列表：仅当前方案时返回内存数据；多方案时合并（按 name 去重）
  static Future<List<ContactItem>> loadRandomPool() async {
    final raw = await SchemeStore.rawPoolItems('contact', 'contacts');
    if (raw == null) return List<ContactItem>.from(contacts);
    final items = raw.map((m) => ContactItem.fromJson(m)).toList();
    return items.isEmpty ? List<ContactItem>.from(contacts) : items;
  }

  static List<ContactItem> search(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) return List.from(contacts);
    return contacts
        .where((c) =>
            c.name.toLowerCase().contains(kw) ||
            c.relation.toLowerCase().contains(kw))
        .toList();
  }

  static int _randomIndex(int length) =>
      DateTime.now().microsecondsSinceEpoch % length;

  static ContactItem pickFrom(List<ContactItem> pool) {
    if (pool.isEmpty) throw StateError('pool is empty');
    return pool[_randomIndex(pool.length)];
  }

  /// 打卡：更新最近联系时间
  static void checkIn(ContactItem contact) {
    contact.lastContact = DateTime.now();
    save();
  }
}
