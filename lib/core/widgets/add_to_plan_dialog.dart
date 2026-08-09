import 'package:flutter/material.dart';
import '../plan_store.dart';
import '../season.dart';

/// 加入计划弹窗：选日期（今天/明天/自定义）+ 备注
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
  final now = DateTime.now();
  final base = DateTime(now.year, now.month, now.day);
  PlanStore.add(PlanItem(
    date: base.add(Duration(days: result.offset)),
    type: type,
    title: title,
    emoji: emoji,
    note: result.note,
  ));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入 ${result.offset == 0 ? '今天' : result.offset == 1 ? '明天' : '后天'}的计划'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PlanDraft {
  final int offset;
  final String note;
  _PlanDraft(this.offset, this.note);
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
  // 默认选中用户当前在首页选择的目标日期（今天/明天/后天）
  late int _offset = targetDateOffset;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final labels = ['今天', '明天', '后天'];
    return AlertDialog(
      title: Text('加入计划 · ${widget.emoji} ${widget.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('计划日期', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(3, (i) {
              final isSelected = _offset == i;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(labels[i]),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _offset = i),
                  selectedColor: primary,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: '备注（可选）',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, _PlanDraft(_offset, _noteCtrl.text.trim())),
          child: const Text('确认加入'),
        ),
      ],
    );
  }
}
