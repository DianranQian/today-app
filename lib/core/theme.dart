import 'package:flutter/material.dart';

/// 「今天做什么」全局主题：暖橙主题色 + 中文字体兜底
ThemeData buildAppTheme() {
  return ThemeData(
    colorSchemeSeed: const Color(0xFFFF6B35),
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
