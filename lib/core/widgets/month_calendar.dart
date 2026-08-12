import 'package:flutter/material.dart';
import '../language.dart';

/// 手写月历对话框：返回选中的日期（date-only），取消返回 null。
///
/// - 标题显示「2026年8月」，左右箭头切换月份
/// - 7 列网格（周日~周六表头），最多 6 行
/// - 今天以主题色圆点标记，初始选中日期以主题色圆底高亮
/// - 无第三方依赖
Future<DateTime?> showMonthCalendar(
  BuildContext context, {
  DateTime? initial,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _MonthCalendarDialog(initial: initial),
  );
}

class _MonthCalendarDialog extends StatefulWidget {
  const _MonthCalendarDialog({this.initial});

  final DateTime? initial;

  @override
  State<_MonthCalendarDialog> createState() => _MonthCalendarDialogState();
}

class _MonthCalendarDialogState extends State<_MonthCalendarDialog> {
  static const _enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  List<String> get _weekdayHeaders => [
        t('日', 'Su'),
        t('一', 'Mo'),
        t('二', 'Tu'),
        t('三', 'We'),
        t('四', 'Th'),
        t('五', 'Fr'),
        t('六', 'Sa'),
      ];

  late int _year;
  late int _month;
  late final DateTime _today = _dateOnly(DateTime.now());
  late final DateTime _initial = _dateOnly(widget.initial ?? DateTime.now());

  @override
  void initState() {
    super.initState();
    _year = _initial.year;
    _month = _initial.month;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _shiftMonth(int delta) {
    setState(() {
      var m = _month + delta;
      var y = _year;
      if (m < 1) {
        m = 12;
        y--;
      } else if (m > 12) {
        m = 1;
        y++;
      }
      _month = m;
      _year = y;
    });
  }

  void _pick(int day) {
    Navigator.of(context).pop(DateTime(_year, _month, day));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    // Dart: 周一=1...周日=7；周日开头的列偏移 = weekday % 7
    final firstWeekday = DateTime(_year, _month, 1).weekday % 7;
    const cellCount = 6 * 7; // 最多 6 行

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: t('上个月', 'Previous Month'),
            onPressed: () => _shiftMonth(-1),
          ),
          Text(t('$_year年$_month月', '${_enMonths[_month - 1]} $_year'),
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: t('下个月', 'Next Month'),
            onPressed: () => _shiftMonth(1),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: List.generate(7, (i) {
                final weekend = i == 0 || i == 6;
                return Expanded(
                  child: Center(
                    child: Text(
                      _weekdayHeaders[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: weekend ? Colors.grey : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
                childAspectRatio: 1.1,
              ),
              itemCount: cellCount,
              itemBuilder: (context, index) {
                final day = index - firstWeekday + 1;
                if (day < 1 || day > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(_year, _month, day);
                final isToday = date == _today;
                final isSelected = date == _initial;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _pick(day),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: isSelected
                        ? BoxDecoration(
                            color: primary, shape: BoxShape.circle)
                        : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSelected
                                ? Colors.white
                                : (isToday ? primary : null),
                            fontWeight:
                                isSelected || isToday ? FontWeight.w600 : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : (isToday ? primary : Colors.transparent),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t('取消', 'Cancel')),
        ),
      ],
    );
  }
}
