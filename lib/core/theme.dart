import 'package:flutter/material.dart';

/// 「今天做什么」主题工厂：四子应用各自的主题色由 seed 派生
///
/// 注意：M3 默认 primary 是 seed 的 40 色调（偏暗），
/// 这里强制 primary = 种子原色，让主题色更亮更艳。
ThemeData buildAppTheme({required Color seed}) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      primary: seed,
    ),
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamilyFallback: const [
      'PingFang SC',
      'Microsoft YaHei',
      'Noto Sans CJK SC',
      'Noto Sans SC',
    ],
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// 子应用默认主题色
abstract class AppSeeds {
  static const eat = Color(0xFFFF6B35); // 吃什么：橙
  static const go = Color(0xFF42A5F5); // 去哪：蓝
  static const wear = Color(0xFFEC407A); // 穿什么：粉
  static const contact = Color(0xFFEF5350); // 联系谁：红
  static const todo = Color(0xFF8D6E63); // 今天待办：棕

  /// 8 色预设色板（通用设置中可选）
  static const palette = <String, Color>{
    '橙': Color(0xFFFF6B35),
    '蓝': Color(0xFF42A5F5),
    '粉': Color(0xFFEC407A),
    '红': Color(0xFFEF5350),
    '青': Color(0xFF26A69A),
    '棕': Color(0xFF8D6E63),
    '靛': Color(0xFF5C6BC0),
    '暖灰': Color(0xFF78909C),
  };
}

/// 主题色语义化派生工具
extension AppColorScheme on ColorScheme {
  /// 浅底（按钮/标签背景）
  Color get primarySoft => primary.withAlpha(25);

  /// 更浅底（胶囊背景）
  Color get primaryTint => primary.withAlpha(40);

  /// 浅色（禁用态等）
  Color get primaryLight => Color.lerp(primary, Colors.white, 0.3)!;

  /// 深色文字
  Color get primaryDark => Color.lerp(primary, Colors.black, 0.35)!;

  /// 浅边框
  Color get primaryBorder => primary.withAlpha(70);
}
