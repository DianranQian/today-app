import 'package:flutter/material.dart';
import '../core/plan_store.dart';

/// 计划清单页（主框架「计划」Tab）
class PlanPage extends StatefulWidget {
  const PlanPage({super.key});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  @override
  Widget build(BuildContext context) {
    final groups = PlanStore.groupByDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    String dayLabel(DateTime d) {
      final diff = d.difference(today).inDays;
      if (diff == 0) return '今天';
      if (diff == 1) return '明天';
      if (diff == 2) return '后天';
      if (diff > 2 && diff < 7) return '本周 · 周${_weekdayCn(d.weekday)}';
      return '${d.month}月${d.day}日';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划清单'),
        centerTitle: true,
        toolbarHeight: 44,
      ),
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📅', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text('还没有计划\n在子应用里选中后点「加入计划」',
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
                for (final (day, items) in groups) ...[
                  Text(dayLabel(day),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  for (final item in items)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Text(item.emoji,
                            style: const TextStyle(fontSize: 26)),
                        title: Text(item.title),
                        subtitle: Text([
                          item.type.label,
                          if (item.note.isNotEmpty) item.note,
                        ].join(' · ')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () {
                            setState(() => PlanStore.remove(item));
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  String _weekdayCn(int w) {
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return names[w - 1];
  }
}
