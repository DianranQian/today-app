import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 当前语言（zh / en），变化时通过 ValueNotifier 通知界面重建
final ValueNotifier<String> langNotifier = ValueNotifier<String>('zh');

String get currentLang => langNotifier.value;

Future<void> loadLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  langNotifier.value = prefs.getString('app_language') ?? 'zh';
}

Future<void> setLanguage(String lang) async {
  langNotifier.value = lang;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_language', lang);
}

/// 双语取词：t('中文', 'English')
String t(String zh, String en) => langNotifier.value == 'zh' ? zh : en;
