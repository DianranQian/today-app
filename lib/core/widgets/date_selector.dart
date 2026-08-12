import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../language.dart';
import '../season.dart';
import 'month_calendar.dart';

/// 目标日期选择：今天/明天/后天（带具体日期）+ 📅 任意日期（全局切换，影响季节推荐）
class TargetDateSelector extends StatelessWidget {
  const TargetDateSelector({super.key, this.enabled = true, this.onChanged});

  final bool enabled;

  /// 切换后通知页面刷新
  final VoidCallback? onChanged;

  /// 选择快捷日期（今天/明天/后天）：清除自定义日期，回退到 offset 逻辑
  static Future<void> setOffset(int offset) async {
    customTargetDate = null;
    targetDateOffset = offset;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('app_target_offset', offset);
    prefs.remove('app_custom_date');
  }

  /// 选择任意日期：customTargetDate 生效（优先于 offset）
  static Future<void> setCustomDate(DateTime date) async {
    customTargetDate = date;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('app_custom_date', date.toIso8601String());
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    targetDateOffset = prefs.getInt('app_target_offset') ?? 0;
    final customStr = prefs.getString('app_custom_date');
    customTargetDate =
        (customStr == null) ? null : DateTime.tryParse(customStr);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quickNames = [
      t('今天'),
      t('明天'),
      t('后天'),
    ];
    final custom = customTargetDate;

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: enabled ? (_) => onTap() : null,
          selectedColor: primary,
          labelStyle: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: selected ? FontWeight.w600 : null,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < 3; i++)
            chip(
              label: '${quickNames[i]} ${formatMd(today.add(Duration(days: i)))}',
              selected: custom == null && targetDateOffset == i,
              onTap: () {
                setOffset(i);
                onChanged?.call();
              },
            ),
          chip(
            label: custom == null
                ? t('📅 选日期')
                : '📅 ${formatMdCn(custom)}',
            selected: custom != null,
            onTap: () async {
              final picked =
                  await showMonthCalendar(context, initial: custom ?? today);
              if (picked == null) return;
              await setCustomDate(picked);
              if (context.mounted) onChanged?.call();
            },
          ),
        ],
      ),
    );
  }
}
