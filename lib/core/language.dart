import 'package:shared_preferences/shared_preferences.dart';

/// 当前语言（zh / en）
String currentLang = 'zh';

Future<void> loadLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  currentLang = prefs.getString('app_language') ?? 'zh';
}

Future<void> setLanguage(String lang) async {
  currentLang = lang;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('app_language', lang);
}

/// 双语取词：t('中文', 'English')
String t(String zh, String en) => currentLang == 'zh' ? zh : en;
