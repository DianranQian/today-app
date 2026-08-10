import 'package:flutter/material.dart';
import '../../core/season.dart';
import '../../core/widgets/date_selector.dart';
import 'todo_models.dart';
import 'todo_data_store.dart';

/// 「今天待办」首页：按日期分组待办清单
class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _add() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _toast('请输入待办内容');
      return;
    }
    TodoDataStore.add(TodoItem(
      title: title,
      note: _noteCtrl.text.trim(),
      date: targetDate,
    ));
    _titleCtrl.clear();
    _noteCtrl.clear();
    setState(() {});
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _dayLabel(DateTime d) {
    final name = quickDayName(d);
    if (name != null) return '$name · ${formatMdCn(d)}';
    return '${formatMdCn(d)} · 周${weekdayCn(d.weekday)}';
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final groups = TodoDataStore.groupByDate();
    final pending = TodoDataStore.pendingCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('今天待办'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: Column(
        children: [
          // 添加区
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    hintText: '添加待办事项...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _add(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _noteCtrl,
                        decoration: const InputDecoration(
                          hintText: '备注（可选）',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _add,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('添加'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 目标日期
                Align(
                  alignment: Alignment.centerLeft,
                  child: TargetDateSelector(
                    onChanged: () => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 概览
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('待办 $pending 项',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (TodoDataStore.items.any((t) => t.done))
                  TextButton(
                    onPressed: () {
                      TodoDataStore.clearDone();
                      setState(() {});
                      _toast('已清空已完成');
                    },
                    child: const Text('清空已完成'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 列表
          Expanded(
            child: groups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 12),
                        Text('还没有待办\n在上方添加一条吧',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                                height: 1.5)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final (day, todos) in groups) ...[
                        Text(_dayLabel(day),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        for (final todo in todos)
                          Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            color: todo.done
                                ? Colors.black.withAlpha(6)
                                : null,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onLongPress: () {
                                TodoDataStore.remove(todo);
                                setState(() {});
                                _toast('已删除');
                              },
                              child: CheckboxListTile(
                                value: todo.done,
                                activeColor: primary,
                                onChanged: (_) {
                                  TodoDataStore.toggle(todo);
                                  setState(() {});
                                },
                                title: Text(
                                  todo.title,
                                  style: TextStyle(
                                    decoration: todo.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: todo.done
                                        ? Colors.grey
                                        : null,
                                  ),
                                ),
                                subtitle: todo.note.isNotEmpty
                                    ? Text(todo.note,
                                        style: const TextStyle(fontSize: 12))
                                    : null,
                                secondary: Text(todo.emoji,
                                    style: const TextStyle(fontSize: 22)),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
