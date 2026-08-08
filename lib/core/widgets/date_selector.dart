import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../season.dart';

/// 目标日期选择：今天/明天/后天（全局切换，影响季节推荐）
class TargetDateSelector extends StatelessWidget {
  const TargetDateSelector({super.key, this.enabled = true, this.onChanged});

  final bool enabled;

  /// 切换后通知页面刷新
  final VoidCallback? onChanged;

  static Future<void> setOffset(int offset) async {
    targetDateOffset = offset;
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('app_target_offset', offset);
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    targetDateOffset = prefs.getInt('app_target_offset') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['今天', '明天', '后天'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(3, (i) {
          final isSelected = targetDateOffset == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: isSelected,
              onSelected: enabled
                  ? (_) {
                      setOffset(i);
                      onChanged?.call();
                    }
                  : null,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
