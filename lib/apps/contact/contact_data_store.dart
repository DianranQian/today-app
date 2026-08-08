import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'contact_models.dart';

class ContactDataStore {
  static List<ContactItem> contacts = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final contactsJson = prefs.getString('contact_contacts');
    if (contactsJson != null && contactsJson.isNotEmpty) {
      try {
        final parsed = (jsonDecode(contactsJson) as List)
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
    saveNow(prefs);
  }

  static Future<void> saveNow([SharedPreferences? prefsInstance]) async {
    final prefs = prefsInstance ?? await SharedPreferences.getInstance();
    prefs.setString('contact_contacts',
        jsonEncode(contacts.map((e) => e.toJson()).toList()));
  }

  static Future<void> save() => saveNow();

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
