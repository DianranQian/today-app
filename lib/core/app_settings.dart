import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

/// 全局设置：四子应用主题色 + API Key（存 prefs）
class AppSettings {
  static String eatColor = '橙';
  static String goColor = '蓝';
  static String wearColor = '粉';
  static String contactColor = '红';
  static String todoColor = '棕';
  static String amapKey = '';
  static String deepseekKey = '';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // 各子应用主题色独立键存储
    eatColor = prefs.getString('app_color_eat') ?? '橙';
    goColor = prefs.getString('app_color_go') ?? '蓝';
    wearColor = prefs.getString('app_color_wear') ?? '粉';
    contactColor = prefs.getString('app_color_contact') ?? '红';
    todoColor = prefs.getString('app_color_todo') ?? '棕';
    amapKey = prefs.getString('app_amap_key') ?? '';
    deepseekKey = prefs.getString('app_deepseek_key') ?? '';
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('app_color_eat', eatColor);
    prefs.setString('app_color_go', goColor);
    prefs.setString('app_color_wear', wearColor);
    prefs.setString('app_color_contact', contactColor);
    prefs.setString('app_color_todo', todoColor);
    prefs.setString('app_amap_key', amapKey);
    prefs.setString('app_deepseek_key', deepseekKey);
  }

  /// 取子应用主题种子色
  static Color seedFor(AppId app) {
    final name = switch (app) {
      AppId.eat => eatColor,
      AppId.go => goColor,
      AppId.wear => wearColor,
      AppId.contact => contactColor,
      AppId.todo => todoColor,
    };
    return AppSeeds.palette[name] ?? AppSeeds.palette['橙']!;
  }
}

enum AppId { eat, go, wear, contact, todo }

extension AppIdExt on AppId {
  String get label {
    switch (this) {
      case AppId.eat: return '今天吃什么';
      case AppId.go: return '今天去哪';
      case AppId.wear: return '今天穿什么';
      case AppId.contact: return '今天联系谁';
      case AppId.todo: return '今天待办';
    }
  }

  String get labelEn {
    switch (this) {
      case AppId.eat: return 'Food';
      case AppId.go: return 'Places';
      case AppId.wear: return 'Outfits';
      case AppId.contact: return 'Contacts';
      case AppId.todo: return 'Tasks';
    }
  }

  String get emoji {
    switch (this) {
      case AppId.eat: return '🍜';
      case AppId.go: return '📍';
      case AppId.wear: return '👕';
      case AppId.contact: return '📞';
      case AppId.todo: return '📋';
    }
  }
}
