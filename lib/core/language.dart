import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/l10n.dart';

/// 当前语言（zh/en/ja...），变化时通过 ValueNotifier 通知界面重建
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

/// 双语取词：t('中文', [可选英文回退])
///
/// key = 中文原文（查字典得到目标语言翻译）。
/// 目标语言未翻译时回退 en → 显式 [en] 参数 → 中文原文。
String t(String zh, [String? en]) {
  final lang = langNotifier.value;
  if (lang == 'zh') return zh;
  final dict = L10n.forLang(lang);
  final v = dict?[zh];
  if (v != null && v.isNotEmpty) return v;
  // 动态/插值场景（如日期、枚举 label）字典查不到时，用显式英文参数
  if (lang == 'en' && en != null) return en;
  final enV = L10n.en[zh];
  if (enV != null && enV.isNotEmpty) return enV;
  if (en != null) return en;
  return zh;
}
