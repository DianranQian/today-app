import 'package:flutter/material.dart';
import '../language.dart';
import '../plan_store.dart';
import '../season.dart';
import 'month_calendar.dart';

/// 加入计划弹窗：选日期（今天/明天/后天/任意日期）+ 备注
Future<void> showAddToPlanDialog(
  BuildContext context, {
  required PlanType type,
  required String title,
  required String emoji,
}) async {
  final result = await showDialog<_PlanDraft>(
    context: context,
    builder: (ctx) => _AddToPlanDialog(
      type: type,
      title: title,
      emoji: emoji,
    ),
  );
  if (result == null) return;
  PlanStore.add(PlanItem(
    date: result.date,
    type: type,
    title: title,
    emoji: emoji,
    note: result.note,
  ));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('已加入 ${formatMdCn(result.date)}的计划',
            'Added to plan for ${formatMdCn(result.date)}')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PlanDraft {
  final DateTime date;
  final String note;
  _PlanDraft(this.date, this.note);
}

class _AddToPlanDialog extends StatefulWidget {
  const _AddToPlanDialog({
    required this.type,
    required this.title,
    required this.emoji,
  });

  final PlanType type;
  final String title;
  final String emoji;

  @override
  State<_AddToPlanDialog> createState() => _AddToPlanDialogState();
}

class _AddToPlanDialogState extends State<_AddToPlanDialog> {
  // 默认选中用户当前在首页选择的目标日期（今天/明天/后天或自定义）
  late DateTime _date = targetDate;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final quickDays = [
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 2)),
    ];
    final quickNames = [
      t('今天'),
      t('明天'),
      t('后天'),
    ];
    final isCustom = !quickDays.any((d) => _sameDay(d, _date));

    ChoiceChip buildChip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : null,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      );
    }

    return AlertDialog(
      title: Text(t('加入计划 · ${widget.emoji} ${widget.title}',
          'Add to Plan · ${widget.emoji} ${widget.title}')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('计划日期'), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < 3; i++)
                buildChip(
                  label: '${quickNames[i]} ${formatMd(quickDays[i])}',
                  selected: !isCustom && _sameDay(_date, quickDays[i]),
                  onTap: () => setState(() => _date = quickDays[i]),
                ),
              buildChip(
                label: isCustom
                    ? '📅 ${formatMdCn(_date)}'
                    : t('📅 选日期'),
                selected: isCustom,
                onTap: () async {
                  final picked =
                      await showMonthCalendar(context, initial: _date);
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: t('备注（可选）'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t('取消'))),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, _PlanDraft(_date, _noteCtrl.text.trim())),
          child: Text(t('确认加入')),
        ),
      ],
    );
  }
}
