/// 通用季节（核心层，供各子应用复用）
enum Season { spring, summer, autumn, winter }

/// 目标日期（全局，存 prefs）
///
/// - [customTargetDate] != null：用户通过月历选择的任意日期（优先）
///   （prefs 键 'app_custom_date'，ISO-8601 字符串，不存在则视为未选）
/// - 否则按 [targetDateOffset]：0=今天，1=明天，2=后天
///   （prefs 键 'app_target_offset'，兼容旧数据）
DateTime? customTargetDate;
int targetDateOffset = 0;

/// 目标日期（date-only）：自定义日期优先，否则今天 + offset 天
DateTime get targetDate {
  final custom = customTargetDate;
  if (custom != null) {
    return DateTime(custom.year, custom.month, custom.day);
  }
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .add(Duration(days: targetDateOffset));
}

Season get currentSeason => seasonFor(DateTime.now());

/// 指定日期的季节
Season seasonFor(DateTime date) {
  final m = date.month;
  if (m >= 3 && m <= 5) return Season.spring;
  if (m >= 6 && m <= 8) return Season.summer;
  if (m >= 9 && m <= 11) return Season.autumn;
  return Season.winter;
}

/// 目标日期季节（随今天/明天/后天或自定义日期切换）
Season get targetSeason => seasonFor(targetDate);

/// 中文星期（周一~周日）
String weekdayCn(int weekday) {
  const names = ['一', '二', '三', '四', '五', '六', '日'];
  return names[weekday - 1];
}

/// 今天/明天/后天（按自然日差，其余返回 null）
String? quickDayName(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  return switch (diff) { 0 => '今天', 1 => '明天', 2 => '后天', _ => null };
}

/// 8月10日
String formatMdCn(DateTime d) => '${d.month}月${d.day}日';

/// 8/10
String formatMd(DateTime d) => '${d.month}/${d.day}';

extension SeasonExt on Season {
  String get label {
    switch (this) {
      case Season.spring: return '春';
      case Season.summer: return '夏';
      case Season.autumn: return '秋';
      case Season.winter: return '冬';
    }
  }

  static Season fromString(String s) {
    switch (s) {
      case 'spring': return Season.spring;
      case 'summer': return Season.summer;
      case 'autumn': return Season.autumn;
      default: return Season.winter;
    }
  }
}
